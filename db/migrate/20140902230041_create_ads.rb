class CreateAds < ActiveRecord::Migration
  def change
    create_table :ads do |t|
      t.string :name
      t.string :title
      t.text :body
      t.string :image
      t.text :target_url
      t.integer :organization_id
      t.boolean :live, default: false, null: false

      t.timestamps
    end
  end
end
