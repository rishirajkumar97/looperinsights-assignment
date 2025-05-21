class Episode < ApplicationRecord
  belongs_to :show

  # Inverse of self-referential associations from Show
  has_one :lastaired_for_show, class_name: "Show", foreign_key: "lastaired_episode_id"
  has_one :upcoming_for_show, class_name: "Show", foreign_key: "upcoming_episode_id"

  validates :name, presence: true
  validates :season, presence: true
  validates :number, presence: true
  validates :type, presence: true
  validates :airdate, presence: true
  validates :airstamp, presence: true

  # Scopes for common queries
  scope :by_season, ->(season) { where(season: season) }
  scope :by_rating, -> { order(avg_rating: :desc) }
  scope :recently_aired, -> { where("airdate <= ?", Date.today).order(airdate: :desc) }
  scope :upcoming, -> { where("airdate > ?", Date.today).order(airdate: :asc) }
end
