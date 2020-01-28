class CreateAbandonedRecords < ActiveRecord::Migration
  def change
    create_table :abandoned_records do |t|
      t.references :bike, index: true
      t.references :user, index: true
      t.references :organization, index: true
      t.datetime :retrieved_at
      t.references :impound_record, index: true
      t.references :initial_abandoned_record, index: true
      t.text :notes
      t.string :address
      t.float :latitude
      t.float :longitude
      t.float :accuracy

      t.timestamps null: false
    end
  end
end
