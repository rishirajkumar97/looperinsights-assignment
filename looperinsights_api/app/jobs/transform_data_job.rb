class TransformDataJob < ApplicationJob
  queue_as :high

  def perform(ids: [], retry_count: 0)
    begin
      # Single loop to extract all data - O(n) complexity
      raw_data_records = RawTvdata.where(id: ids, status: 0)

      # Global accumulators - will be populated from the extraction maps
      @countries_data = []
      @networks_data = []
      @webchannels_data = []
      @shows_data = []
      @episodes_data = []

      # Single pass through all records to extract all required data
      extract_all_data(raw_data_records)

      # Build countries first
      build_countries

      # Build networks and webchannels - no lookup needed, import handles associations
      build_networks
      build_webchannels

      build_shows
      build_episodes

      # Mark records as processed
      raw_data_records.update_all(status: 1)
      true
    rescue StandardError => e
      Rails.logger.error("Error occurred - #{e}")
      init_exponential_fall_back(ids, retry_count)
    end
  end

  private

  # Single loop to extract all data with object deduplication - O(n) complexity
  def extract_all_data(raw_data_records)
    # Use hashes for deduplication during extraction
    countries_map = {}
    networks_map = {}
    webchannels_map = {}
    shows_map = {}

    raw_data_records.each do |record|
      data = record.raw_data
      next unless data.present?

      # Extract and deduplicate countries
      extract_and_deduplicate_countries(data, countries_map)

      # Extract and deduplicate networks/webchannels with country references
      extract_and_deduplicate_distributions(data, countries_map, networks_map, webchannels_map)

      # Extract and deduplicate shows with network/webchannel references
      extract_and_deduplicate_shows(data, networks_map, webchannels_map, shows_map)

      # Extract episodes with show references
      extract_episodes(data, shows_map)
    end

    # Convert maps to arrays for import
    @countries_data = countries_map.values
    @networks_data = networks_map.values
    @webchannels_data = webchannels_map.values
    @shows_data = shows_map.values
  end

  # Extract countries with deduplication using composite key
  def extract_and_deduplicate_countries(data, countries_map)
    # Network country
    if data.dig("show", "network", "country").present?
      country_data = data.dig("show", "network", "country")
      country_key = "#{country_data['code']}_#{country_data['name']}_#{country_data['timezone']}"

      unless countries_map[country_key]
        countries_map[country_key] = Country.new(
          name: country_data["name"],
          timezone: country_data["timezone"],
          code: country_data["code"]
        )
      end
    end

    # WebChannel country
    if data.dig("show", "webChannel", "country").present?
      country_data = data.dig("show", "webChannel", "country")
      country_key = "#{country_data['code']}_#{country_data['name']}_#{country_data['timezone']}"

      unless countries_map[country_key]
        countries_map[country_key] = Country.new(
          name: country_data["name"],
          timezone: country_data["timezone"],
          code: country_data["code"]
        )
      end
    end
  end

  # Extract networks/webchannels with country object references
  def extract_and_deduplicate_distributions(data, countries_map, networks_map, webchannels_map)
    # Network
    if data.dig("show", "network").present?
      network_data = data.dig("show", "network")
      network_key = "#{network_data['id']}_#{network_data['name']}_#{network_data['officialSite']}"

      unless networks_map[network_key]
        # Find country object reference
        country_obj = nil
        if network_data["country"].present?
          country_data = network_data["country"]
          country_key = "#{country_data['code']}_#{country_data['name']}_#{country_data['timezone']}"
          country_obj = countries_map[country_key]
        end

        networks_map[network_key] = Network.new(
          id: network_data["id"],
          name: network_data["name"],
          official_site: network_data["officialSite"],
          country: country_obj
        )
      end
    end

    # WebChannel
    if data.dig("show", "webChannel").present?
      webchannel_data = data.dig("show", "webChannel")
      webchannel_key = "#{webchannel_data['id']}_#{webchannel_data['name']}_#{webchannel_data['officialSite']}"

      unless webchannels_map[webchannel_key]
        # Find country object reference
        country_obj = nil
        if webchannel_data["country"].present?
          country_data = webchannel_data["country"]
          country_key = "#{country_data['code']}_#{country_data['name']}_#{country_data['timezone']}"
          country_obj = countries_map[country_key]
        end

        webchannels_map[webchannel_key] = WebChannel.new(
          id: webchannel_data["id"],
          name: webchannel_data["name"],
          official_site: webchannel_data["officialSite"],
          country: country_obj
        )
      end
    end
  end

  # Extract shows with network/webchannel object references (keeping latest by updated)
  def extract_and_deduplicate_shows(data, networks_map, webchannels_map, shows_map)
    show_data = data["show"]
    return unless show_data.present?

    show_id = show_data["id"]
    updated_time = Time.at(show_data["updated"].to_i)

    # Only keep the latest version of each show
    if shows_map[show_id].nil? || shows_map[show_id].updated < updated_time
      # Find network/webchannel object references
      network_obj = nil
      if show_data.dig("network").present?
        network_data = show_data["network"]
        network_key = "#{network_data['id']}_#{network_data['name']}_#{network_data['officialSite']}"
        network_obj = networks_map[network_key]
      end

      webchannel_obj = nil
      if show_data.dig("webChannel").present?
        webchannel_data = show_data["webChannel"]
        webchannel_key = "#{webchannel_data['id']}_#{webchannel_data['name']}_#{webchannel_data['officialSite']}"
        webchannel_obj = webchannels_map[webchannel_key]
      end

      shows_map[show_id] = Show.new(
        id: show_data["id"],
        name: show_data["name"],
        url: show_data["url"],
        type: show_data["type"],
        language: show_data["language"],
        ended: show_data["ended"],
        image_original_url: show_data.dig("image", "original"),
        image_medium_url: show_data.dig("image", "medium"),
        genres: show_data["genres"] || [],
        avg_rating: show_data.dig("rating", "average"),
        status: show_data["status"],
        network: network_obj,
        web_channel: webchannel_obj,
        summary: show_data["summary"],
        updated: updated_time,
        schedule: show_data["schedule"].to_h.to_json,
        premiered: show_data["premiered"] ? Date.parse(show_data["premiered"]) : nil,
        official_site: show_data["officialSite"],
        avg_runtime: show_data["averageRuntime"] || show_data["runtime"],
        runtime: show_data["runtime"],
        tvrage_id: show_data.dig("externals", "tvrage"),
        imdb_id: show_data.dig("externals", "imdb"),
        thetvdb_id: show_data.dig("externals", "thetvdb"),
        lastaired_episode_id: show_data.dig("_links", "self", "previousepisode")&.[](/\d+$/),
        upcoming_episode_id: show_data.dig("_links", "self", "nextepisode")&.[](/\d+$/)
      )
    end
  end

  # Extract episodes with show object references
  def extract_episodes(data, shows_map)
    episode_data = data.except("show")
    return unless episode_data["id"].present?

    show_obj = shows_map[data.dig("show", "id")] if data.dig("show", "id").present?

    @episodes_data << Episode.new(
      id: episode_data["id"],
      name: episode_data["name"],
      season: episode_data["season"],
      number: episode_data["number"],
      type: episode_data["type"],
      runtime: episode_data["runtime"],
      airdate: episode_data["airdate"],
      airstamp: episode_data["airstamp"],
      official_site: episode_data["officialSite"],
      avg_rating: episode_data.dig("rating", "average"),
      summary: episode_data["summary"],
      show: show_obj,
      image_original_url: episode_data.dig("image", "original"),
      image_medium_url: episode_data.dig("image", "medium")
    )
  end

  # Extract countries from a single record - Build actual Country objects for import gem
  def extract_countries_from_record(data)
    # Network country
    if data.dig("show", "network", "country").present?
      country_data = data.dig("show", "network", "country")
      country = Country.new(
        name: country_data["name"],
        timezone: country_data["timezone"],
        code: country_data["code"]
      )
      @countries_data << country
    end

    # WebChannel country
    if data.dig("show", "webChannel", "country").present?
      country_data = data.dig("show", "webChannel", "country")
      country = Country.new(
        name: country_data["name"],
        timezone: country_data["timezone"],
        code: country_data["code"]
      )
      @countries_data << country
    end
  end

  # Extract network and webchannel distribution data - Build actual objects with Country associations
  def extract_distributions_from_record(data)
    # Network data - build actual objects
    if data.dig("show", "network").present?
      network = data.dig("show", "network")

      # Find the corresponding country object from @countries_data
      network_country = nil
      if network["country"].present?
        country_data = network["country"]
        network_country = @countries_data.find do |country|
          country.name == country_data["name"] &&
          country.timezone == country_data["timezone"] &&
          country.code == country_data["code"]
        end
      end

      # Build network object with country association
      network_obj = Network.new(
        id: network["id"],
        name: network["name"],
        official_site: network["officialSite"],
        country: network_country
      )

      @networks_data << network_obj
    end

    # WebChannel data - build actual objects
    if data.dig("show", "webChannel").present?
      webchannel = data.dig("show", "webChannel")

      # Find the corresponding country object from @countries_data
      webchannel_country = nil
      if webchannel["country"].present?
        country_data = webchannel["country"]
        webchannel_country = @countries_data.find do |country|
          country.name == country_data["name"] &&
          country.timezone == country_data["timezone"] &&
          country.code == country_data["code"]
        end
      end

      # Build webchannel object with country association
      webchannel_obj = WebChannel.new(
        id: webchannel["id"],
        name: webchannel["name"],
        official_site: webchannel["officialSite"],
        country: webchannel_country
      )

      @webchannels_data << webchannel_obj
    end
  end

  # Extract show data (keeping latest by updated timestamp)
  def extract_show_from_record(data)
    show = data["show"]
    return unless show.present?

    show_id = show["id"]
    updated_time = Time.at(show["updated"].to_i)

    # Only keep the latest version of each show
    if @shows_data[show_id].nil? || @shows_data[show_id][:updated] < updated_time
      @shows_data[show_id] = {
        id: show["id"],
        name: show["name"],
        url: show["url"],
        type: show["type"],
        language: show["language"],
        ended: show["ended"],
        image_original_url: show.dig("image", "original"),
        image_medium_url: show.dig("image", "medium"),
        genres: show["genres"] || [],
        avg_rating: show.dig("rating", "average"),
        status: show["status"],
        network_id: show.dig("network", "id"),
        webchannel_id: show.dig("webChannel", "id"),
        summary: show["summary"],
        updated: updated_time,
        schedule: show["schedule"].to_h.to_json,
        premiered: show["premiered"] ? Date.parse(show["premiered"]) : nil,
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

  # Extract episode data - Build complete nested object hierarchy
  def extract_episode_from_record(data)
    episode_data = data.except("show") # Episode data is at root level
    return unless episode_data["id"].present?

    # Build the complete Show object with all its associations
    show_data = data["show"]
    show_obj = build_show_object(show_data) if show_data.present?

    # Build Episode object with associated Show
    episode_obj = Episode.new(
      id: episode_data["id"],
      name: episode_data["name"],
      season: episode_data["season"],
      number: episode_data["number"],
      type: episode_data["type"],
      runtime: episode_data["runtime"],
      airdate: episode_data["airdate"],
      airstamp: episode_data["airstamp"],
      official_site: episode_data["officialSite"],
      avg_rating: episode_data.dig("rating", "average"),
      summary: episode_data["summary"],
      show: show_obj,
      image_original_url: episode_data.dig("image", "original"),
      image_medium_url: episode_data.dig("image", "medium")
    )

    @episodes_data << episode_obj
  end

  # Helper method to build complete Show object with all nested associations
  def build_show_object(show_data)
    # Build Network object if present
    network_obj = nil
    if show_data.dig("network").present?
      network_data = show_data["network"]

      # Build Country for Network
      network_country = nil
      if network_data["country"].present?
        network_country = find_or_build_country(network_data["country"])
      end

      network_obj = Network.new(
        id: network_data["id"],
        name: network_data["name"],
        official_site: network_data["officialSite"],
        country: network_country
      )
    end

    # Build WebChannel object if present
    webchannel_obj = nil
    if show_data.dig("webChannel").present?
      webchannel_data = show_data["webChannel"]

      # Build Country for WebChannel
      webchannel_country = nil
      if webchannel_data["country"].present?
        webchannel_country = find_or_build_country(webchannel_data["country"])
      end

      webchannel_obj = WebChannel.new(
        id: webchannel_data["id"],
        name: webchannel_data["name"],
        official_site: webchannel_data["officialSite"],
        country: webchannel_country
      )
    end

    # Build Show object with all associations
    Show.new(
      id: show_data["id"],
      name: show_data["name"],
      url: show_data["url"],
      type: show_data["type"],
      language: show_data["language"],
      ended: show_data["ended"],
      image_original_url: show_data.dig("image", "original"),
      image_medium_url: show_data.dig("image", "medium"),
      genres: show_data["genres"] || [],
      avg_rating: show_data.dig("rating", "average"),
      status: show_data["status"],
      network: network_obj,
      webchannel: webchannel_obj,
      summary: show_data["summary"],
      updated: Time.at(show_data["updated"].to_i),
      schedule: show_data["schedule"].to_h.to_json,
      premiered: show_data["premiered"] ? Date.parse(show_data["premiered"]) : nil,
      official_site: show_data["officialSite"],
      avg_runtime: show_data["averageRuntime"] || show_data["runtime"],
      runtime: show_data["runtime"],
      tvrage_id: show_data.dig("externals", "tvrage"),
      imdb_id: show_data.dig("externals", "imdb"),
      thetvdb_id: show_data.dig("externals", "thetvdb"),
      lastaired_episode_id: show_data.dig("_links", "self", "previousepisode")&.[](/\d+$/),
      upcoming_episode_id: show_data.dig("_links", "self", "nextepisode")&.[](/\d+$/)
    )
  end

  # Helper to find existing country object or create new one
  def find_or_build_country(country_data)
    # First try to find in already extracted countries
    existing_country = @countries_data.find do |country|
      country.name == country_data["name"] &&
      country.timezone == country_data["timezone"] &&
      country.code == country_data["code"]
    end

    # If not found, create new one
    unless existing_country
      existing_country = Country.new(
        name: country_data["name"],
        timezone: country_data["timezone"],
        code: country_data["code"]
      )
      @countries_data << existing_country
    end

    existing_country
  end

  # Build countries using import gem with correct conflict resolution
  def build_countries
    return [] if @countries_data.empty?

    countries_array = @countries_data.to_a

    # Remove id from objects to avoid conflict detection on wrong column
    countries_array.each { |country| country.id = nil }

    # Use on_duplicate_key_update with the actual unique constraint columns
    result = Country.import(
      countries_array,
      on_duplicate_key_update: {
        conflict_target: [ :code, :timezone, :name ],  # Specify the actual unique constraint
        columns: [ :name ]  # Dummy update column
      },
      validate: false
    )

    raise StandardError, "Error while importing countries" unless result.failed_instances.empty?

    # Now ALL IDs are returned (both newly inserted and existing)
    returned_ids = result.ids

    raise StandardError, "Count Mismatch in importing countries" if returned_ids&.length != countries_array&.length

    true
  end

  # Build reverse lookup hash for countries: {[code, name, timezone] => id} - Optimized DB format
  def build_country_reverse_lookup(country_ids)
    # Single database read with optimized pluck format
    countries_data = Country.where(id: country_ids)
                           .pluck(Arel.sql("ARRAY[code, name, timezone], id"))

    # Direct hash conversion - no loops needed
    countries_data.to_h
  end

  # Build networks using import gem - objects with associations work perfectly
  def build_networks
    return [] if @networks_data.empty?

    # Use import gem with associations - it handles country relationships automatically
    result = Network.import(
      @networks_data,
      on_duplicate_key_ignore: true,
      validate: false
    )

    raise StandardError, "Error while importing networks" unless result.failed_instances.empty?

    true
  end

  # Build webchannels using import gem - objects with associations work perfectly
  def build_webchannels
    return [] if @webchannels_data.empty?

    # Use import gem with associations - it handles country relationships automatically
    result = WebChannel.import(
      @webchannels_data,
      on_duplicate_key_ignore: true,
      validate: false
    )

    raise StandardError, "Error while importing webchannels" unless result.failed_instances.empty?

    true
  end

  # Build shows using import gem - objects with associations work perfectly
  def build_shows
    return [] if @shows_data.empty?

    # Use import gem with associations - it handles network/webchannel relationships automatically
    result = Show.import(
      @shows_data,
      on_duplicate_key_update: {
        conflict_target: [ :id ],  # Show ID is the unique identifier
        columns: [ :name, :url, :type, :language, :ended, :image_original_url,
                  :image_medium_url, :genres, :avg_rating, :status, :network_id,
                  :web_channel_id, :summary, :updated, :schedule, :premiered,
                  :official_site, :avg_runtime, :runtime, :tvrage_id, :imdb_id,
                  :thetvdb_id, :lastaired_episode_id, :upcoming_episode_id ]
      },
      validate: false
    )

    raise StandardError, "Error while importing shows" unless result.failed_instances.empty?

    true
  end

  # Build episodes using import gem - objects with associations work perfectly
  def build_episodes
    return [] if @episodes_data.empty?

    # Use import gem with associations - it handles show relationships automatically
    result = Episode.import(
      @episodes_data,
      on_duplicate_key_update: {
        conflict_target: [ :id ],  # Episode ID is the unique identifier
        columns: [ :name, :season, :number, :type, :runtime, :airdate,
                  :airstamp, :official_site, :avg_rating, :summary,
                  :show_id, :image_original_url, :image_medium_url ]
      },
      validate: false
    )

    raise StandardError, "Error while importing episodes" unless result.failed_instances.empty?

    true
  end

  # Method for fall back and fault tolerance - with exponential backoff algorithm
  def init_exponential_fall_back(ids, retry_count)
    retry_count += 1
    if retry_count < 2
      status = 2 # failed queue but can reprocess automatically
    else
      status = 3 # completely errored
    end

    RawTvdata.where(id: ids).update_all(status: status, retry_count: retry_count)

    if retry_count < 2
      left, right = ids.each_slice((ids.size/2.0).round).to_a
      TransformDataJob.perform_later(ids: left, retry_count: retry_count)
      TransformDataJob.perform_later(ids: right, retry_count: retry_count)
    end
  end
end
