require "sidekiq-scheduler"
class SyncTvMazeDataJob < ApplicationJob
  queue_as :default

  API_URL = "https://api.tvmaze.com/schedule?date=".freeze
  RATE_LIMIT_DELAY = 0.5 # 20 calls / 10 seconds => 1 call per 0.5 seconds

  def perform(*args)
    initial_run = RawTvdata.count.zero?

    dates = if initial_run
              (Date.today..(Date.today + 90)).to_a # Initial Feed from today to plus 90 days in future
    else
              [ (Date.today + 91) ] # Subsequent Runs just run for the 91st day from today
    end

    all_records = []

    dates.each_with_index do |date, index|
      Rails.logger.info "Fetching data for #{date}"
      records = get_upcoming_show(date)
      all_records.concat(records)

      sleep(RATE_LIMIT_DELAY) if index < dates.size - 1
    end

    if all_records.any?
      RawTvdata.insert_all(
        all_records,
        unique_by: :id # assumes `id` is primary key or has unique index
      )
    end

    inserted_ids = all_records.map { |r| r[:id] }.uniq
    TransformDataJob.perform_later(ids: inserted_ids, retry_count: 0) if inserted_ids.present?

    true
  end

  private
  # get_upcoming_show method
  # Gets the upcoming shows data from the schedule api for a given date
  # Paramters:
  # date - the date to pull the shows airing on from
  def get_upcoming_show(date)
    response = Faraday.get("#{API_URL}#{date}")

    if response.success?
      json_array = JSON.parse(response.body)

      json_array.map do |episode_data|
        {
          id: episode_data["id"],                    # Use episode ID from JSON
          raw_data: episode_data,                    # Store full JSON in raw_data
          status: 0,
          retry_count: 0
        }
      end
    else
      Rails.logger.error "Failed to fetch data for #{date}: #{response.status}"
      []
    end
  rescue => e
    Rails.logger.error "Exception fetching data for #{date}: #{e.message}"
    []
  end
end
