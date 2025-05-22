class AddWebChannel < ActiveRecord::Migration[7.2]
  def change
    create_table :web_channels, id: :bigint do |t|
      t.string :name, null: false
      t.integer :country_id, null: false
      t.string :official_site
    end

    remove_column :networks, :webchannel
    remove_column :networks, :dvdcountry

    add_index :web_channels, :name
  end
end
