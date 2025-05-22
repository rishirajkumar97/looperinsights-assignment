# == Schema Information
#
# Table name: web_channels
#
#  id            :bigint           not null, primary key
#  name          :string           not null
#  country_id    :integer          not null
#  official_site :string
#
class WebChannel < ApplicationRecord
  belongs_to :country
  has_many :shows, dependent: :destroy

  validates :name, presence: true
end
