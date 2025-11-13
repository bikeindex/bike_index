# == Schema Information
#
# Table name: blog_content_tags
# Database name: primary
#
#  id             :bigint           not null, primary key
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  blog_id        :bigint
#  content_tag_id :bigint
#
# Indexes
#
#  index_blog_content_tags_on_blog_id         (blog_id)
#  index_blog_content_tags_on_content_tag_id  (content_tag_id)
#
class BlogContentTag < ApplicationRecord
  belongs_to :blog
  belongs_to :content_tag

  validates :blog_id, uniqueness: {scope: :content_tag_id}
end
