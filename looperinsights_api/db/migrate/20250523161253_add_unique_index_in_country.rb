class AddUniqueIndexInCountry < ActiveRecord::Migration[7.2]
  def change
    add_index :countries, [ :code, :timezone, :name ], unique: true
    # Ex:- add_index("admin_users", "username")
  end
end
