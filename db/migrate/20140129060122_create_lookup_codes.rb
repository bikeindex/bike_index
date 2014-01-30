class CreateLookupCodes < ActiveRecord::Migration
  def change
    create_table :lookup_codes do |t|
      t.string :xyz_code
      t.timestamps
    end
    
    add_index :lookup_codes, :xyz_code, :unique => true
  end
end
