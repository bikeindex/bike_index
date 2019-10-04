class CreateExternalRegistryBikes < ActiveRecord::Migration
  def change
    create_table :external_registry_bikes do |t|
      t.string :type, null: false, index: true
      t.belongs_to :country, null: false, index: true

      t.string :serial_number, null: false
      t.string :serial_normalized, null: false, index: true
      t.string :external_id, null: false, index: true
      t.string :additional_registration

      t.datetime :date_stolen
      t.string :category
      t.string :cycle_type
      t.string :description
      t.string :frame_colors
      t.string :frame_model
      t.string :location_found
      t.string :mnfg_name
      t.string :status
      t.jsonb :info_hash, default: {}

      t.timestamps null: false
    end
  end
end
