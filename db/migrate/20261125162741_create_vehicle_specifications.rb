class CreateVehicleSpecifications < ActiveRecord::Migration[8.1]
  def change
    create_table :vehicle_specifications do |t|
      t.references :bike_obj, polymorphic: true, null: false, index: {unique: true}
      t.references :bikebook_model, foreign_key: false
      t.string :bikebook_market

      t.timestamps
    end
  end
end
