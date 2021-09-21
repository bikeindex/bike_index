class AddExternalUpdatedAtToExternalBikes < ActiveRecord::Migration[5.2]
  def change
    add_column :external_registry_bikes, :external_updated_at, :datetime
  end
end
