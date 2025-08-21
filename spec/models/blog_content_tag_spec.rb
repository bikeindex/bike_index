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
require "rails_helper"

RSpec.describe BlogContentTag, type: :model do
  describe "valid factory" do
    let(:blog_content_tag) { FactoryBot.create(:blog_content_tag) }
    it "is valid" do
      expect(blog_content_tag).to be_valid
    end
  end
end
