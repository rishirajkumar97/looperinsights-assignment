# == Schema Information
#
# Table name: countries
#
#  id       :bigint           not null, primary key
#  name     :string           not null
#  code     :string           not null
#  timezone :string           not null
#
class Country < ApplicationRecord
  has_many :networks, dependent: :destroy
  has_many :shows, through: :networks

  validates :name, presence: true
  validates :code, presence: true
  validates :timezone, presence: true
end
