class AddRawTvData < ActiveRecord::Migration[7.2]
  def change
    create_table :raw_tvdata, id: :bigint do |t|
      t.jsonb :raw_data
      t.integer :status, default: 0
      t.integer :retry_count, default: 0
    end
  end
end
