class ChangeNullableInEpisodes < ActiveRecord::Migration[7.2]
  def up
    change_column :episodes, :number, :integer, null: true
  end
  def down
    change_column :episodes, :number, :integer, null: false
  end
end
