class CreateBikeCodes < ActiveRecord::Migration
  def change
    create_table :bike_codes do |t|
      t.integer :kind, default: 0, null: 0
      t.string :code
      t.references :bike, index: true
      t.references :organization
      t.references :user

      t.timestamps null: false
    end
  end
end
