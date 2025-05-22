class ChangeNullableInShows < ActiveRecord::Migration[7.2]
  def up
    change_column :shows, :network_id, :bigint, null: true
    change_column :shows, :language, :string, null: true
  end

  def down
    change_column :shows, :network_id, :bigint, null: false
    change_column :shows, :language, :string, null: false
  end
end
