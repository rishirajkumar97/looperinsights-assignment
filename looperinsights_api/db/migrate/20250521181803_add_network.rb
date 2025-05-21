class AddNetwork < ActiveRecord::Migration[7.2]
  def change
    create_table :networks, id: :bigint do |t|
      t.string :name, null: false
      t.integer :country_id, null: false
      t.string :official_site
      t.string :dvdcountry
      t.string :webchannel
    end

    create_table :countries, id: :bigint do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.string :timezone, null: false
    end
    add_index :networks, :name
    add_index :countries, :name
  end
end
