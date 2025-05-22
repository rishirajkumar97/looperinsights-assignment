class ChangeScheduletoJsonb < ActiveRecord::Migration[7.2]
  def change
    change_column :shows, :schedule, :jsonb
  end
end
