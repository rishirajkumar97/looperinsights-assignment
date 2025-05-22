# == Schema Information
#
# Table name: networks
#
#  id            :bigint           not null, primary key
#  name          :string           not null
#  country_id    :integer          not null
#  official_site :string
#
class Network < ApplicationRecord
  belongs_to :country, optional: true
  has_many :shows, dependent: :destroy

  validates :name, presence: true
end
