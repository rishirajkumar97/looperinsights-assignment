class ChangeCountryidToNullable < ActiveRecord::Migration[7.2]
  def change
    change_column :web_channels, :country_id, :bigint, null: true
  end
end
