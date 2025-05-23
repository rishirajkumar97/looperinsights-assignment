FactoryBot.define do
  factory :raw_tvdata do
    sequence(:id) { |n| n + 1000 }
    raw_data { { "id" => id, "name" => "Episode #{id}", "airdate" => Date.today.to_s } }
    status { 0 }
    retry_count { 0 }
  end
end