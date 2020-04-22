class CreateImpoundRecordUpdates < ActiveRecord::Migration[5.2]
  def change
    create_table :impound_record_updates do |t|
      t.references :impound_record, index: true
      t.references :user, index: true
      t.references :location, index: true
      t.integer :kind
      t.text :note

      t.timestamps
    end
  end
end
