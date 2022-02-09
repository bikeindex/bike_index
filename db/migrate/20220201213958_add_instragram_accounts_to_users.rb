class AddInstragramAccountsToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :show_instagram, :boolean, default: false
    add_column :users, :instagram, :string
  end
end
