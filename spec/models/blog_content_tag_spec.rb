require "rails_helper"

RSpec.describe BlogContentTag, type: :model do
  describe "valid factory" do
    let(:blog_content_tag) { FactoryBot.create(:blog_content_tag) }
    it "is valid" do
      expect(blog_content_tag).to be_valid
    end
  end
end
