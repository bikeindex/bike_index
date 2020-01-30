class CreateImpoundRecords < ActiveRecord::Migration[4.2]
  def change
    create_table :impound_records do |t|
      t.references :bike, index: true
      t.references :user, index: true
      t.references :organization, index: true
      t.datetime :retrieved_at

      t.timestamps null: false
    end
  end
end
