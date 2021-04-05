class CreateContentTags < ActiveRecord::Migration[5.2]
  def change
    create_table :content_tags do |t|
      t.string :name
      t.string :slug
      t.text :description
      t.integer :priority

      t.timestamps
    end
  end
end
