class RenameColumnInShow < ActiveRecord::Migration[7.2]
  def change
    rename_column :shows, :webchannel_id, :web_channel_id
    # Ex:- rename_column("admin_users", "pasword","hashed_pasword")
  end
end
