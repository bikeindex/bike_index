class CreateMailSnippets < ActiveRecord::Migration
  def change
    create_table :mail_snippets do |t|
      t.string :name 
      t.boolean :is_enabled, default: false, null: false
      t.boolean :is_location_triggered, default: false, null: false
      t.text :body
      t.string :address
      t.float :latitude
      t.float :longitude
      t.integer :proximity_radius

      t.timestamps
    end
  end
end
