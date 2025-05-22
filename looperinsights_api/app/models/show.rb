class Show < ApplicationRecord
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
end
