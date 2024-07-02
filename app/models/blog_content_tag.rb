# == Schema Information
#
# Table name: blog_content_tags
#
#  id             :bigint           not null, primary key
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  blog_id        :bigint
#  content_tag_id :bigint
#
class BlogContentTag < ApplicationRecord
  belongs_to :blog
  belongs_to :content_tag

  validates :blog_id, uniqueness: {scope: :content_tag_id}
end
