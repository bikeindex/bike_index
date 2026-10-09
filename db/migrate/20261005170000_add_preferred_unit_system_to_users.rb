class AddPreferredUnitSystemToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :preferred_unit_system, :integer
  end
end
