class CreateContentTags < ActiveRecord::Migration[5.2]
  def change
    create_table :content_tags do |t|
      t.text :name
      t.text :slug
      t.integer :priority

      t.timestamps
    end
  end
end
