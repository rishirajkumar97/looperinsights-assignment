class Country < ApplicationRecord
  has_many :networks, dependent: :destroy
  has_many :shows, through: :networks

  validates :name, presence: true
  validates :code, presence: true
  validates :timezone, presence: true
end
