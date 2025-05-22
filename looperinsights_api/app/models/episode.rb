# == Schema Information
#
# Table name: episodes
#
#  id                 :bigint           not null, primary key
#  name               :string           not null
#  season             :integer          not null
#  number             :integer          not null
#  type               :string           not null
#  runtime            :integer
#  airdate            :date             not null
#  airstamp           :datetime         not null
#  official_site      :string
#  avg_rating         :float
#  summary            :text
#  image_original_url :string
#  image_medium_url   :string
#  show_id            :bigint           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
class Episode < ApplicationRecord
  self.inheritance_column = :_type_disabled

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

  def self.ransackable_attributes(auth_object = nil)
    column_names - [ "created_at", "updated_at" ]
  end

  # Optional: if you want to allow sorting/filtering on associations
  def self.ransackable_associations(auth_object = nil)
    %w[show network web_channel]
  end
end
