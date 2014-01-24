class AddExampleToOwnerships < ActiveRecord::Migration
  def change
    add_column :ownerships, :example, :boolean, default: false, null: false
  end
end
