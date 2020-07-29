require "rails_helper"

RSpec.describe NewsController, type: :request do
  let(:base_url) { "/news" }
  context "legacy" do
    describe "index" do
      it "renders" do
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template("index")
      end
    end

    describe "show" do
      let(:user) { FactoryBot.create(:user) }
      let(:blog) { Blog.create(title: "foo title", body: "ummmmm good", user_id: user.id, old_title_slug: "an-older-title") }
      context "title slug" do
        it "renders" do
          get "#{base_url}/#{blog.title_slug}"
          expect(response.status).to eq(200)
          expect(response).to render_template("show")
        end
      end
      context "old title slug" do
        it "renders" do
          get "#{base_url}/#{blog.old_title_slug}"
          expect(response.status).to eq(200)
          expect(response).to render_template("show")
        end
      end
      context "id" do
        it "renders" do
          get "#{base_url}/#{blog.id}"
          expect(response.status).to eq(200)
          expect(response).to render_template("show")
        end
      end
    end
  end

  context "revised" do
    describe "index" do
      context "html" do
        it "renders" do
          get base_url
          expect(response.status).to eq(200)
          expect(response).to render_template("index")
        end
      end
      context "given a language selection" do
        it "renders blog posts in that language" do
          FactoryBot.create(:blog, :published)
          FactoryBot.create(:blog, :published, :dutch)

          get base_url, params: { language: "nl" }

          expect(response.status).to eq(200)
          expect(response).to render_template("index")
          expect(assigns(:blogs).length).to eq(1)
        end
      end
      context "xml" do
        it "redirects to atom" do
          get base_url, params: { format: :xml }
          expect(response).to redirect_to(news_index_path(format: "atom"))
        end
      end
      context "atom" do
        it "renders" do
          FactoryBot.create(:blog, :published)
          get base_url, params: { format: :atom }
          expect(response.status).to eq(200)
        end
      end
    end

    describe "show" do
      let(:user) { FactoryBot.create(:user) }
      let(:blog) { Blog.create(title: "foo title", body: "ummmmm good", user_id: user.id, old_title_slug: "an-older-title") }
      it "renders" do
        get "#{base_url}/#{blog.title_slug}"
        expect(response.status).to eq(200)
        expect(response).to render_template("show")
      end
      context "is info" do
        let(:blog) { FactoryBot.create(:blog, is_info: true) }
        it "redirects to info" do
          get "#{base_url}/#{blog.title_slug}"
          expect(response).to redirect_to(info_path(blog.to_param))
        end
      end
    end
  end
end
