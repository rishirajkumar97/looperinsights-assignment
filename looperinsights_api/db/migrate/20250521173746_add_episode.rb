class AddEpisode < ActiveRecord::Migration[7.2]
  def change
    create_table :episodes, id: :bigint do |t|
      t.string :name, null: false
      t.integer :season, null: false
      t.integer :number, null: false
      t.string :type, null: false
      t.integer :runtime
      t.date :airdate, null: false
      t.datetime :airstamp, null: false
      t.string :official_site
      t.float :avg_rating
      t.text :summary
      t.string :image_original_url
      t.string :image_medium_url
      t.bigint :show_id, null: false
      
      t.timestamps
    end
    
    # Add indexes for common queries
    add_index :episodes, :name
    add_index :episodes, :airdate
    add_index :episodes, :avg_rating
    add_index :episodes, :type
    add_index :episodes, :show_id
  end
end
