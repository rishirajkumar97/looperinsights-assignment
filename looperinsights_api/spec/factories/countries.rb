# spec/factories/countries.rb
FactoryBot.define do
  factory :country do
    sequence(:name) { |n| "Country#{n}" }
    sequence(:code) { |n| "C#{n}" }
    timezone { "UTC" }
  end
end
