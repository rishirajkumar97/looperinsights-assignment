# == Schema Information
#
# Table name: shows
#
#  id                   :bigint           not null, primary key
#  name                 :string           not null
#  url                  :string           not null
#  type                 :string           not null
#  language             :string           not null
#  status               :string
#  runtime              :integer
#  avg_runtime          :integer
#  premiered            :date
#  ended                :date
#  official_site        :string
#  avg_rating           :float
#  schedule             :jsonb
#  imdb_id              :string
#  thetvdb_id           :integer
#  tvrage_id            :integer
#  summary              :text
#  updated              :datetime
#  lastaired_episode_id :bigint
#  upcoming_episode_id  :bigint
#  image_original_url   :string
#  image_medium_url     :string
#  genres               :text             default([]), is an Array
#  network_id           :bigint           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  webchannel_id        :bigint
#
class Show < ApplicationRecord
  self.inheritance_column = :_type_disabled
  belongs_to :network
  belongs_to :web_channel
  has_many :episodes, dependent: :destroy

  # Self-referential associations for last aired and upcoming episodes
  belongs_to :lastaired_episode, class_name: "Episode", optional: true
  belongs_to :upcoming_episode, class_name: "Episode", optional: true

  # For easy access to country
  has_one :country, through: :network

  validates :name, presence: true
  validates :url, presence: true, uniqueness: true
  validates :type, presence: true
  validates :language, presence: true

  def self.ransackable_attributes(auth_object = nil)
    column_names - [ "created_at", "updated_at" ]
  end

  # Optional: if you want to allow sorting/filtering on associations
  def self.ransackable_associations(auth_object = nil)
    %w[network web_channel episode]
  end
end
