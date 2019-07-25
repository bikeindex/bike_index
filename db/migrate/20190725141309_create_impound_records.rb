class CreateImpoundRecords < ActiveRecord::Migration
  def change
    create_table :impound_records do |t|
      t.references :bike
      t.references :user
      t.references :organization
      t.datetime :retrieved_at

      t.timestamps null: false
    end
  end
end
