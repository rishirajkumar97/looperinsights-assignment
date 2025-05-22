class TransformDataJob < ApplicationJob
  queue_as :high

  def perform(ids: [])
    # With the incoming ids check if they are processed or not to perform consistency and prevent further processing
    # Remove the already processed ids.
    # Utilize Bulk Inserts to Insert countries first, then the networks, then the shows and last the episodes.
    # Use a fall back exponential fall back mechanism to ensure that we have fault tolerance and a last effort to insert each record one by one.
    # Transform them into the Show, Episode, Country and Network data and update if necessary or the updated has changed.
    raw_data_records = RawTvdata.where(id: ids).where.not(status: 1)
    begin
      accumulator = {
        countries: [],
        networks: [],
        shows: [],
        episodes: [],
        webchannels: []
      }

      # Extract Country
      raw_data_records.each do |record|
        data = record.data
        next unless data.present?
        network_country = extract_country(data, "network") if data.dig("show", "network").present?
        webchannel_country = extract_country(data, "webChannel") if data.dig("show", "webChannel").present?
        accumulator[:countries] << network_country if network_country
        accumulator[:countries] << webchannel_country if webchannel_country
      end
      country_ids = upsert_countries(accumulator[:countries])
      country_hash = Country.where(id: country_ids).as_json # Convert to json to prevent querying of the database additionally

      country_hash = countries.map do |c|
        [c["id"], c.except("id")]
      end.to_h

      reverse_lookup_country = country_hash.each_with_object({}) do |(id, attrs), acc|
        key = [attrs[:code], attrs[:name], attrs[:timezone]]
        acc[key] = id
      end
      
      raw_data_records.each do |record|
        data = record.data
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
      shows = records.map { |r| r["show"] }

      # Step 2: Group by show ID
      grouped_by_id = shows.group_by { |s| s["id"] }

      # Step 3: For each group, select the latest one by updated_at
      latest_shows_by_id = grouped_by_id.transform_values do |dupes|
        dupes.max_by { |s| Time.at(s["updated_at"].to_i) }
      end
      # Process Episodes - Last Effort
    rescue StandardError
      # start the fallback of exponential backoff -> might only be needed on initial run
    end

  end

  private

  # Extracts the country information of the network
  # type - represents either network or webchannel
  def extract_network_country(data, type)
    c = data.dig("show", type , "country")
    return nil unless c
    {
      name: c["name"],
      timezone: c["timezone"],
      code: c["code"]
    }
  end

  def extract_distribution(data, type, reverse_lookup_country)
    c = data.dig("show", type)
    return nil unless c

    country_data = data.dig("show", type, "country")
    country_id = if country_data.nil?
      nil
    else
      reverse_lookup_country[[country_data["code"],country_data["name"],country_data["timezone"]]]
    end

    {
      id: c["id"],
      official_site: c["official_site"],
      name: c["name"],
      country_id: country_id
    }
  end

  # countries- list of countries hash to be inserted from the incoming data
  def upsert_countries(countries)
    return if countries.blank?
    countries = countries.uniq
    existing = Country.all.pluck(:name, :code, :timezone, :id)
    existing_lookup = existing.map { |name, code, timezone, id| [[name, code, timezone], id] }.to_h
    existing_set = existing_lookup.keys.to_set

    new_data = []
    existing_ids = []

    countries.each do |c|
      key = [c[:name], c[:code], c[:timezone]]
      if existing_set.include?(key)
        existing_ids << existing_lookup[key]
      else
        new_data << c
      end
    end

    result = Country.upsert_all(new_data) if new_data.any?
    raise StandardError, "Error while upserting countries" if result == false || result.nil?

    # Combine existing IDs with newly inserted IDs
    all_ids = existing_ids
    all_ids += result.result.rows.flatten if result&.result&.rows&.any?

    return all_ids
  end

  # Upsert Distribution - upserts either Network or WebChannel
  # data - the new incoming data records to be ingested
  # klass_name - the name of the klass as the distribution can be flipped between network and WebChannel
  def upsert_distribution(data, klass_name)
    klass = klass.constantize
    return if data.blank?
    distributors = data.uniq
    existing = klass.all.pluck(:name, :official_site, :country_id, :id)
    existing_lookup = existing.map { |name, official_site, country_id, id| [[name, official_site, country_id], id] }.to_h
    existing_set = existing_lookup.keys.to_set

    new_data = []
    existing_ids = []

    data.each do |c|
      key = [c[:name], c[:official_site], c[:country_id]]
      if existing_set.include?(key)
        existing_ids << existing_lookup[key]
      else
        new_data << c
      end
    end

    result = klass.upsert_all(new_data) if new_data.any?
    raise StandardError, "Error while upserting #{klass_name}" if result == false || result.nil?

    # Combine existing IDs with newly inserted IDs
    all_ids = existing_ids
    all_ids += result.result.rows.flatten if result&.result&.rows&.any?

    return all_ids
  end
end
