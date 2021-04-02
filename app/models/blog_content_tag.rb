class BlogContentTag < ApplicationRecord
  belongs_to :blog
  belongs_to :content_tag

  validates :blog_id, uniqueness: {scope: :content_tag_id}
end
