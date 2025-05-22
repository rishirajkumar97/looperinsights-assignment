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
  belongs_to :country, optional: true
  has_many :shows, dependent: :destroy

  validates :name, presence: true

  def self.ransackable_attributes(auth_object = nil)
    column_names - [ "created_at", "updated_at" ]
  end
end
