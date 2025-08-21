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
# Indexes
#
#  index_blog_content_tags_on_blog_id         (blog_id)
#  index_blog_content_tags_on_content_tag_id  (content_tag_id)
#
FactoryBot.define do
  factory :blog_content_tag do
    blog { FactoryBot.create(:blog) }
    content_tag { FactoryBot.create(:content_tag) }
  end
end
