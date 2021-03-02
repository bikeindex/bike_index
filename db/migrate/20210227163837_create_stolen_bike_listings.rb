class CreateStolenBikeListings < ActiveRecord::Migration[5.2]
  def change
    create_table :stolen_bike_listings do |t|
      t.references :bike
      t.references :initial_listing
      t.references :primary_frame_color
      t.references :secondary_frame_color
      t.references :tertiary_frame_color
      t.integer :listing_order

      # Manufacturer
      t.references :manufacturer
      t.string :manufacturer_other
      t.string :mnfg_name

      t.text :frame_model
      t.string :frame_size
      t.string :frame_size_unit
      t.float :frame_size_number

      # stolen bike listing specific
      t.datetime :listed_at
      t.integer :amount_cents
      t.string :currency
      t.text :listing_text
      t.jsonb :data

      t.integer :line
      t.integer :group

      t.timestamps
    end
  end
end
