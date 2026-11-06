class CreatePosRegistrationMatches < ActiveRecord::Migration[8.1]
  def change
    create_table :pos_registration_matches do |t|
      t.references :duplicate_bike_group
      # No standalone index - the unique index below starts with bike_id
      t.references :bike, null: false, index: false
      t.references :pos_bike, null: false
      t.integer :status, default: 0, null: false
      t.text :review_reasons, array: true, default: [], null: false

      t.timestamps
    end
    add_index :pos_registration_matches, %i[bike_id pos_bike_id], unique: true
  end
end
