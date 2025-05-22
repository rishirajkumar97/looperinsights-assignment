FactoryBot.define do
  factory :web_channel do
    sequence(:name) { |n| "WebChannel#{n}" }
    official_site { "https://web.example.com" }
    association :country
  end
end
