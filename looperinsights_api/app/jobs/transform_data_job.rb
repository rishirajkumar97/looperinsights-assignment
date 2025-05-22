class TransformDataJob < ApplicationJob
  queue_as :high

  def perform(ids: [], retry_count: 0)
    begin
      # With the incoming ids check if they are processed or not to perform consistency and prevent further processing
      # Remove the already processed ids.
      # Utilize Bulk Inserts to Insert countries first, then the networks, then the shows and last the episodes.
      # Use a fall back exponential fall back mechanism to ensure that we have fault tolerance and a last effort to insert each record one by one.
      # Transform them into the Show, Episode, Country and Network data and update if necessary or the updated has changed.
      raw_data_records = RawTvdata.where(id: ids).where.not(status: 1)
      accumulator = {
        countries: [],
        networks: [],
        webchannels: []
      }

      # Extract Country
      raw_data_records.each do |record|
        data = record.raw_data
        next unless data.present?
        network_country = extract_country(data, "network") if data.dig("show", "network").present?
        webchannel_country = extract_country(data, "webChannel") if data.dig("show", "webChannel").present?
        accumulator[:countries] << network_country if network_country
        accumulator[:countries] << webchannel_country if webchannel_country
      end
      country_ids = upsert_countries(accumulator[:countries])
      country_hash = Country.where(id: country_ids).as_json # Convert to json to prevent querying of the database additionally
      country_hash = country_hash.map do |c|
        [ c["id"], c.except("id") ]
      end.to_h

      reverse_lookup_country = country_hash.each_with_object({}) do |(id, attrs), acc|
        key = [ attrs["code"], attrs["name"], attrs["timezone"] ]
        acc[key] = id
      end

      raw_data_records.each do |record|
        data = record.raw_data
        next unless data.present?
        network = extract_distribution(data, "network", reverse_lookup_country) if data.dig("show", "network").present?
        webchannel = extract_distribution(data, "webChannel", reverse_lookup_country) if data.dig("show", "webChannel").present?
        accumulator[:networks] << network if network
        accumulator[:webchannels] << webchannel if webchannel
      end

      network_ids = upsert_distribution(accumulator[:networks], "Network")
      webchannel_ids = upsert_distribution(accumulator[:webchannels], "WebChannel")

      # Process Shows - With exclusion principle of updated with unix stamp to pick the most recent

      # Step 1: Extract all show hashes
      records = raw_data_records.pluck(:raw_data).as_json
      shows = records.map { |r| r["show"] }

      # Step 2: Group by show ID
      grouped_by_id = shows.group_by { |s| s["id"] }

      # Step 3: For each group, select the latest one by updated_at
      latest_shows_by_id = grouped_by_id.transform_values do |dupes|
        dupes.max_by { |s| Time.at(s["updated"].to_i) }
      end

      shows_to_upsert = extract_show_data(latest_shows_by_id)
      show_ids = upsert_shows(shows_to_upsert)

      show_records = Show.where(id: ids)

      episodes_to_upsert = extract_episode_data(
        raw_data_records.pluck(
            :raw_data
          ).as_json
        )
      episode_ids = upsert_episodes(episodes_to_upsert)
      raw_data_records.update_all(status: 1)
      true
    rescue StandardError
      init_exponential_fall_back(ids, retry_count) # initiates exponential backoff
    end
  end

  private

  # Extracts the country information of the distributor type
  # type - represents either network or webchannel
  def extract_country(data, type)
    c = data.dig("show", type, "country")
    return nil unless c
    {
      name: c["name"],
      timezone: c["timezone"],
      code: c["code"]
    }
  end

  # Extract Distributiond ata based on the type
  # data to be ingested
  # type - Network / WEbchannel distribution type
  # reverselookup - hash with country,code,timezone as key and the value as country id for O(1) lookup
  def extract_distribution(data, type, reverse_lookup_country)
    c = data.dig("show", type)
    return nil unless c

    country_data = data.dig("show", type, "country")
    country_id = if country_data.nil?
      nil
    else
      reverse_lookup_country[[ country_data["code"], country_data["name"], country_data["timezone"] ]]
    end

    {
      id: c["id"],
      official_site: c["officialSite"],
      name: c["name"],
      country_id: country_id
    }
  end

  # Extract Show Data
  def extract_show_data(data)
    data.map do |id, show|
      {
        id: show["id"], # assuming you want to keep the show ID for reference
        name: show["name"],
        url: show["url"],
        type: show["type"],
        language: show["language"],
        ended: show["ended"], # could be nil
        image_original_url: show.dig("image", "original"),
        image_medium_url: show.dig("image", "medium"),
        genres: show["genres"] || [], # array, ensure default empty
        avg_rating: show.dig("rating", "average"),  # nested rating average
        status: show["status"],
        network_id: show.dig("network", "id"),  # might be nil
        webchannel_id: show.dig("webChannel", "id"), # might be nil
        summary: show["summary"],
        updated: Time.at(show["updated"].to_i), # convert unix timestamp to datetime
        schedule: show["schedule"].to_h.to_json, # stored as json in DB
        premiered: show["premiered"] ? Date.parse(show["premiered"]) : nil, # parse date string
        official_site: show["officialSite"],
        avg_runtime: show["averageRuntime"] || show["runtime"],
        runtime: show["runtime"],
        tvrage_id: show.dig("externals", "tvrage"),
        imdb_id: show.dig("externals", "imdb"),
        thetvdb_id: show.dig("externals", "thetvdb"),
        lastaired_episode_id: show.dig("_links", "self", "previousepisode")&.[](/\d+$/),
        upcoming_episode_id: show.dig("_links", "self", "nextepisode")&.[](/\d+$/)
      }
    end
  end

  # Extract Episode Data
  def extract_episode_data(data)
    data.map do |record|
      {
        id: record["id"], # assuming you want to keep the show ID for reference
        name: record["name"],
        season: record["season"],
        number: record["number"],
        type: record["type"],
        runtime: record["runtime"],
        airdate: record["airdate"],
        airstamp: record["airstamp"],
        official_site: record["officialSite"],
        avg_rating: record.dig("rating", "average"),
        summary: record["summary"],
        show_id: record.dig("show", "id"),
        image_original_url: record.dig("image", "original"),
        image_medium_url: record.dig("image", "medium")
      }
    end
  end
  # countries- list of countries hash to be inserted from the incoming data
  def upsert_countries(countries)
    return if countries.blank?
    countries = countries.uniq
    existing = Country.all.pluck(:name, :code, :timezone, :id)
    existing_lookup = existing.map { |name, code, timezone, id| [ [ name, code, timezone ], id ] }.to_h
    existing_set = existing_lookup.keys.to_set

    new_data = []
    existing_ids = []

    countries.each do |c|
      key = [ c[:name], c[:code], c[:timezone] ]
      if existing_set.include?(key)
        existing_ids << existing_lookup[key]
      else
        new_data << c
      end
    end

    result = Country.upsert_all(new_data) if new_data.any?
    raise StandardError, "Error while upserting countries" if new_data.any? && (result == false || result.result.rows.flatten&.empty?)

    # Combine existing IDs with newly inserted IDs
    all_ids = existing_ids
    all_ids += result.result.rows.flatten if result&.result&.rows&.any?

    all_ids
  end

  # Upsert Distribution - upserts either Network or WebChannel
  # data - the new incoming data records to be ingested
  # klass_name - the name of the klass as the distribution can be flipped between network and WebChannel
  def upsert_distribution(data, klass_name)
    klass = klass_name.constantize
    return if data.blank?
    distributors = data.uniq
    existing = klass.all.pluck(:name, :official_site, :country_id, :id)
    existing_lookup = existing.map { |name, official_site, country_id, id| [ [ name, official_site, country_id ], id ] }.to_h
    existing_set = existing_lookup.keys.to_set

    new_data = []
    existing_ids = []

    distributors.each do |c|
      key = [ c[:name], c[:official_site], c[:country_id] ]
      if existing_set.include?(key)
        existing_ids << existing_lookup[key]
      else
        new_data << c
      end
    end

    result = klass.upsert_all(new_data) if new_data.any?
    raise StandardError, "Error while upserting #{klass_name}" if new_data.any? && (result == false || result.nil?)

    # Combine existing IDs with newly inserted IDs
    all_ids = existing_ids
    all_ids += result.result.rows.flatten if result&.result&.rows&.any?

    all_ids
  end

  # method to upsert shows model / table
  # data - the hash of the shows with extracted information
  def upsert_shows(data)
    # Extract all incoming IDs
    incoming_ids = data.map { |show| show[:id] }

    # Fetch existing shows' updated_at from DB for these IDs
    existing_records = Show.where(id: incoming_ids).pluck(:id, :updated).to_h
    # This results in a hash like { 1 => Time1, 2 => Time2, ... }

    # Reject records from new_data if the existing updated_at is newer (i.e., incoming is older)
    filtered_data = data.reject do |show|
      existing_updated_at = existing_records[show[:id]]
      existing_updated_at && existing_updated_at > show[:updated]&.to_time
    end

    result = Show.upsert_all(filtered_data) if filtered_data.any? # only insert if the incoming data has updated or new shows
    raise StandardError, "Error while upserting episodes" if filtered_data.any? && (result == false || result.nil?)
    all_ids = result.result.rows.flatten if result&.result&.rows&.any?

    all_ids
  end

  # method to upsert episode model / table
  # data - the hash of the episodes with extracted information
  def upsert_episodes(data)
    # Extract all incoming IDs
    incoming_ids = data.map { |show| show[:id] }

    # Fetch existing shows' updated_at from DB for these IDs
    existing_records = Episode.where(id: incoming_ids).pluck(:id).to_a
    # This results in a hash like { 1 => Time1, 2 => Time2, ... }

    # Reject records from new_data if the existing data_id is present in older episode pulls
    filtered_data = data.reject do |episode|
      episode_id = episode[:id]
      existing_records.include? episode_id
    end

    result = Episode.upsert_all(filtered_data) if filtered_data.any? # only insert if the incoming data has updated or new shows

    raise StandardError, "Error while upserting episodes" if filtered_data.any? && (result == false || result.nil?)
    all_ids = result.result.rows.flatten if result&.result&.rows&.any?

    all_ids
  end

  # Method for fall back and fault tolerance - with exponential backoff algorithm paragdim.
  # ids - the ids of the raw data to process
  # retry_count - the current retry_count
  def init_exponential_fall_back(ids, retry_count)
    retry_count += 1
    if retry_count < 2
      status = 2 # failed queue but can reprocess automatically
    else
      status = 3 # completely errored
    end

    records = RawTvdata.where(id: ids).update_all(status: status, retry_count: retry_count)
    if retry_count < 2
      left, right = ids.each_slice((ids.size/2.0).round).to_a # Split ids to two halves
      TransformDataJob.perform_later(ids: left, retry_count: retry_count)
      TransformDataJob.perform_later(ids: right, retry_count: retry_count)
    end
  end
end
