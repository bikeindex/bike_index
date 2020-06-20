require "rails_helper"

RSpec.describe Admin::NewsController, type: :request do
  let(:base_url) { "/admin/news/" }
  let(:blog) { FactoryBot.create(:blog) }
  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end

  describe "show" do
    it "redirects to edit" do
      get "#{base_url}/#{blog.to_param}"
      expect(response).to redirect_to(edit_admin_news_path(blog.to_param))
    end
  end

  describe "edit" do
    it "renders" do
      get "#{base_url}/#{blog.to_param}/edit"
      expect(response.status).to eq(200)
      expect(response).to render_template(:edit)
    end
  end

  describe "update" do
    it "updates available attributes" do
      blog_attrs = {
        title: "new title thing stuff",
        body: "<p>html</p>",
        language: "en",
      }
      put "#{base_url}/#{blog.to_param}", params: { blog: blog_attrs }
      blog.reload
      expect(blog.title).to eq blog_attrs[:title]
      expect(blog.body).to eq blog_attrs[:body]
    end
    describe "update info" do
      let(:blog_attrs) { { is_info: true } }
      it "switches to be info" do
        put "#{base_url}/#{blog.to_param}", params: { blog: blog_attrs }
        blog.reload
        expect(blog.info?).to be_truthy
      end
    end
  end
end
