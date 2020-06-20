require "rails_helper"

RSpec.describe InfoController, type: :request do
  let(:base_url) { "/info" }
  describe "show" do
    let(:blog) { FactoryBot.create(:blog, is_info: true) }
    it "renders" do
      get "#{base_url}/#{blog.title_slug}"
      expect(response.status).to eq(200)
      expect(response).to render_template("show")
    end
    context "blog" do
      let(:blog) { FactoryBot.create(:blog) }
      it "redirects" do
        get "#{base_url}/#{blog.title_slug}"
        expect(response).to redirect_to(info_path(blog.to_param))
      end
    end
  end
end
