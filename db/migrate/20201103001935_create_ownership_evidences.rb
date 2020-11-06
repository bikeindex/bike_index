class CreateOwnershipEvidences < ActiveRecord::Migration[5.2]
  def change
    create_table :ownership_evidences do |t|
      t.references :impound_record, index: true
      t.references :stolen_record, index: true
      t.references :user, index: true
      t.text :serial_number
      t.text :serial_normalized
      t.boolean :made_without_serial, default: false

      t.text :bike_description
      t.text :message
      t.json :data

      t.integer :status

      t.timestamps
    end
    # change_column :bikes, :serial_number, :string, :text
    # add_column :public_images, :kind, :integer, default: 0
  end
end
