FactoryBot.define do
  factory :episode do
    name { "Pilot" }
    season { 1 }
    number { 1 }
    type { "Regular" }
    runtime { 45 }
    airdate { Date.today }
    airstamp { DateTime.now }
    official_site { "http://example.com/ep" }
    avg_rating { rand(5.0..10.0).round(1) }
    summary { "Intro to the show." }
    image_original_url { "http://img.com/original.jpg" }
    image_medium_url { "http://img.com/medium.jpg" }
    show
  end
end
