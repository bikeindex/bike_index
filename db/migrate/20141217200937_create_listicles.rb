class CreateListicles < ActiveRecord::Migration
  def change
    create_table :listicles do |t|
      t.integer :list_order
      t.text :body
      t.integer :blog_id
      t.string :image
      t.text :title
      t.text :body_html
      t.integer :image_width
      t.integer :image_height
      t.text :image_credits
      t.text :image_credits_html
      t.integer :crop_top_offset

      t.timestamps
    end
    add_column :blogs, :is_listicle, :boolean, default: false, null: false
  end
end
