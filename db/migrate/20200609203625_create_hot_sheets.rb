class CreateHotSheets < ActiveRecord::Migration[5.2]
  def change
    create_table :hot_sheets do |t|
      t.references :organization
      t.jsonb :stolen_record_ids
      t.jsonb :recipient_ids
      t.string :delivery_status

      t.timestamps
    end
  end
end
