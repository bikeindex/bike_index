class AddSerialNormalizedToExternalRegistryBike < ActiveRecord::Migration
  def change
    add_column :external_registry_bikes,
               :serial_normalized,
               :string,
               null: false,
               index: true
  end
end
