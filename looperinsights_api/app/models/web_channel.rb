class WebChannel < ApplicationRecord
  belongs_to :country
  has_many :shows, dependent: :destroy

  validates :name, presence: true
end
