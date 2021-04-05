class CreateBlogContentTags < ActiveRecord::Migration[5.2]
  def change
    create_table :blog_content_tags do |t|
      t.references :blog, index: true
      t.references :content_tag, index: true

      t.timestamps
    end
  end
end
