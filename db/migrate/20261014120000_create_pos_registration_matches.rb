class CreatePosRegistrationMatches < ActiveRecord::Migration[8.1]
  def change
    create_table :pos_registration_matches do |t|
      # No standalone index - the unique index below starts with bike_id
      t.references :bike, null: false, index: false
      t.references :pos_bike, null: false
      t.references :user, null: false
      t.integer :status, default: 0, null: false

      t.timestamps
    end
    add_index :pos_registration_matches, %i[bike_id pos_bike_id], unique: true
  end
end
