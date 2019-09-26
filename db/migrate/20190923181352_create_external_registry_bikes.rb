class CreateExternalRegistryBikes < ActiveRecord::Migration
  def change
    create_table :external_registry_bikes do |t|
      t.belongs_to :external_registry, null: false, index: true
      t.string :serial_number, null: false, index: true
      t.string :serial_normalized, null: false, index: true
      t.string :external_id, null: false, index: true
      t.string :source_name
      t.string :source_unique_id

      t.string :category
      t.string :description
      t.string :frame_colors
      t.string :frame_model
      t.string :image_url
      t.string :is_stock_img
      t.string :large_img
      t.string :location_found
      t.string :mnfg_name
      t.string :status
      t.string :thumb
      t.string :thumb_url
      t.string :cycle_type
      t.string :url
      t.datetime :date_stolen

      t.timestamps null: false
    end

    add_foreign_key :external_registry_bikes,
                    :external_registries,
                    column: :external_registry_id,
                    on_delete: :cascade
  end
end
