class AddWebChannelIdtoShows < ActiveRecord::Migration[7.2]
  def change
    add_column :shows, :webchannel_id, :bigint
  end
end
