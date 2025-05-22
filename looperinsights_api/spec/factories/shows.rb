FactoryBot.define do
  factory :show do
    sequence(:name) { |n| "Show#{n}" }
    sequence(:url) { |n| "http://show#{n}.com" }
    type { "Drama" }
    language { "English" }
    status { "Running" }
    runtime { 60 }
    avg_runtime { 60 }
    premiered { Date.today - 1.year }
    ended { nil }
    official_site { "https://show.example.com" }
    avg_rating { 8.5 }
    schedule { { time: "20:00", days: [ "Monday" ] } }
    summary { "A great show." }
    updated { Time.now }
    genres { [ "Drama", "Mystery" ] }
    association :network
    association :web_channel
  end
end
