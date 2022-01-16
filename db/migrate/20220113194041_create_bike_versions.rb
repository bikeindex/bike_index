class CreateBikeVersions < ActiveRecord::Migration[5.2]
  def change
    create_table :bike_versions do |t|
      t.references :owner, index: true
      t.references :bike, index: true
      t.references :paint, index: true
      t.references :primary_frame_color, index: true
      t.references :secondary_frame_color, index: true
      t.references :tertiary_frame_color, index: true
      t.references :front_wheel_size, index: true
      t.references :rear_wheel_size, index: true
      t.references :rear_gear_type, index: true
      t.references :front_gear_type, index: true

      t.references :manufacturer, index: true
      t.string :manufacturer_other
      t.string :mnfg_name
      t.string :extra_registration_number # There might be a chance this changes between versions

      t.string :name
      t.text :description

      t.text :frame_model
      t.integer :year
      t.string :frame_size
      t.string :frame_size_unit
      t.float :frame_size_number

      t.boolean :rear_tire_narrow
      t.boolean :front_tire_narrow
      t.integer :number_of_seats
      t.boolean :belt_drive
      t.boolean :coaster_brake

      t.integer :frame_material
      t.integer :handlebar_type
      t.integer :cycle_type
      t.integer :propulsion_type

      t.text :cached_data
      t.text :thumb_path
      t.text :video_embed

      t.integer :listing_order
      t.integer :visibility, default: 0
      t.integer :status, default: 0

      t.datetime :deleted_at
      t.datetime :start_at
      t.datetime :end_at

      t.timestamps
    end
    add_reference :components, :bike_version, index: true
    add_column :components, :mnfg_name, :string
  end
end
