class CreateOwnershipEvidences < ActiveRecord::Migration[5.2]
  def change
    create_table :ownership_evidences do |t|
      t.references :impound_record, index: true
      t.references :stolen_record, index: true
      t.references :user, index: true

      # Serial stuff - mirrors Bike serial stuff
      t.string :serial_number
      t.string :serial_normalized
      t.boolean :made_without_serial, default: false

      t.text :bike_description
      t.text :message
      t.json :data

      t.integer :status
      t.datetime :submitted_at

      t.timestamps
    end

    # add_column :public_images, :kind, :integer, default: 0
  end
end
