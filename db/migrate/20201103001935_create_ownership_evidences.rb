class CreateOwnershipEvidences < ActiveRecord::Migration[5.2]
  def change
    create_table :ownership_evidences do |t|
      t.references :impound_record, index: true
      t.references :stolen_record, index: true
      t.references :user, index: true
      t.text :serial
      t.text :bike_description
      t.text :message

      t.timestamps
    end
  end
end
