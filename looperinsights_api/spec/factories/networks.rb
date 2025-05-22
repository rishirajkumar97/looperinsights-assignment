# spec/factories/networks.rb
FactoryBot.define do
  factory :network do
    sequence(:name) { |n| "Network#{n}" }
    official_site { "https://example.com" }
    association :country
  end
end
