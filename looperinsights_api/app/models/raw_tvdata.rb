# == Schema Information
#
# Table name: raw_tvdata
#
#  id          :bigint           not null, primary key
#  raw_data    :jsonb
#  status      :integer          default(0)
#  retry_count :integer          default(0)
#
class RawTvdata < ApplicationRecord
  enum status: { to_process: 0, completed: 1, failed: 2, errored: 3 }
  has_one :episode
end
