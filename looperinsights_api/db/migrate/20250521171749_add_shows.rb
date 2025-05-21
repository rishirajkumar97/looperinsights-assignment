class AddShows < ActiveRecord::Migration[7.2]
  def change
    create_table :shows, id: :bigint do |t|
      t.string :name, null: false
      t.string :url, null: false
      t.string :type, null: false
      t.string :language, null: false
      t.string :status
      t.integer :runtime
      t.integer :avg_runtime
      t.date :premiered
      t.date :ended
      t.string :official_site
      t.float :avg_rating
      t.json :schedule
      t.string :imdb_id
      t.integer :thetvdb_id
      t.integer :tvrage_id
      t.text :summary
      t.datetime :updated
      t.bigint :lastaired_episode_id
      t.bigint :upcoming_episode_id
      t.string :image_original_url
      t.string :image_medium_url
      t.text :genres, array: true, default: []
      t.bigint :network_id, null: false

      t.timestamps
    end

    # Add indexes for common queries
    add_index :shows, :name
    add_index :shows, :url, unique: true
    add_index :shows, :status
    add_index :shows, :premiered
    add_index :shows, :type
    add_index :shows, :updated
    add_index :shows, :network_id

    # Add index for external IDs for quick lookups
    add_index :shows, :imdb_id, unique: true, where: "imdb_id IS NOT NULL"
    add_index :shows, :thetvdb_id, unique: true, where: "thetvdb_id IS NOT NULL"
    add_index :shows, :tvrage_id, unique: true, where: "tvrage_id IS NOT NULL"
  end
end
