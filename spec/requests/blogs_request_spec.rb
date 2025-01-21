require "rails_helper"

base_url = "/blogs"
RSpec.describe BlogsController, type: :request do
  describe "index" do
    it "redirects" do
      get base_url
      expect(response).to redirect_to(news_index_url)
    end
  end

  describe "show" do
    it "redirects" do
      user = FactoryBot.create(:user)
      blog = Blog.create(title: "foo title", body: "ummmmm good", user_id: user.id)
      get "#{base_url}/#{blog.title_slug}"
      expect(response).to redirect_to(news_url(blog.title_slug))
    end
  end
end
