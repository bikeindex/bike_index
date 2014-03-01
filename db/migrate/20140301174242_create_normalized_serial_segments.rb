class CreateNormalizedSerialSegments < ActiveRecord::Migration
  def change
    create_table :normalized_serial_segments do |t|
      t.string :segment 
      t.integer :bike_id

      t.timestamps
    end
  end
end
