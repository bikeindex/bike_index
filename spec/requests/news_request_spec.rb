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
      context "with tags" do
        let(:blog) { FactoryBot.create(:blog, published: true) }
        let(:tag_common) { FactoryBot.create(:content_tag, name: "Zebra", priority: 5) }
        let(:tag_rare) { FactoryBot.create(:content_tag, name: "Aardvark", priority: 1) }
        it "lists each post's tags most common first" do
          [tag_rare, tag_common].each { |tag| BlogContentTag.create!(blog:, content_tag: tag) }
          get base_url
          expect(response.body.index("Zebra")).to be < response.body.index("Aardvark")
        end
      end
    end

    describe "show" do
      let(:user) { FactoryBot.create(:user) }
      let(:blog) { Blog.create(title: "foo title", body: "ummmmm good", user_id: user.id, old_title_slug: "an-older-title", secondary_title: "yeah-that-title") }
      context "title slug" do
        it "renders" do
          get "#{base_url}/#{blog.title_slug}"
          expect(response.status).to eq(200)
          expect(response).to render_template("show")
          expect(assigns(:show_discuss)).to be_falsey
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
      context "secondary title" do
        it "renders" do
          get "#{base_url}/#{blog.secondary_title}"
          expect(response.status).to eq(200)
          expect(response).to render_template("show")
        end
      end
      it "renders" do
        get "#{base_url}/#{blog.title_slug}"
        expect(response.status).to eq(200)
        expect(response).to render_template("show")
      end
      context "is info" do
        let!(:blog) { FactoryBot.create(:blog, info_kind: true) }
        it "redirects to info" do
          get "#{base_url}/#{blog.title_slug}"
          expect(response).to redirect_to(info_path(blog.to_param))
        end
      end
    end
  end

  describe "index" do
    context "html" do
      it "renders" do
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template("index")
        expect(response.body).to match(/type=.application.atom.xml/)
      end
    end
    context "given a tag" do
      let!(:content_tag) { FactoryBot.create(:content_tag, name: "Bike Recovery") }
      let!(:blog1) { FactoryBot.create(:blog, :published, content_tag_names: "Bike recovery") }
      let!(:blog2) { FactoryBot.create(:blog, :published) }
      it "renders blog posts matching tag" do
        expect(blog1.reload.content_tags.pluck(:id)).to eq([content_tag.id])
        get base_url, params: {search_tags: " bike-recovery"}

        expect(response.status).to eq(200)
        expect(response).to render_template("index")
        expect(assigns(:search_tags).pluck(:id)).to eq([content_tag.id])
        expect(assigns(:blogs).pluck(:id)).to eq([blog1.id])
      end
    end
    context "given a language selection" do
      it "renders blog posts in that language" do
        FactoryBot.create(:blog, :published)
        FactoryBot.create(:blog, :published, :dutch)

        get base_url, params: {language: "nl"}

        expect(response.status).to eq(200)
        expect(response).to render_template("index")
        expect(assigns(:blogs).length).to eq(1)
      end
    end
    context "xml" do
      it "redirects to atom" do
        get base_url, params: {format: :xml}
        expect(response).to redirect_to(news_index_path(format: "atom"))
      end
    end
    context "atom" do
      it "renders" do
        FactoryBot.create(:blog, :published)
        get base_url, params: {format: :atom}
        expect(response.status).to eq(200)
        get "/news.atom"
        expect(response.status).to eq(200)
      end
      context "with caching", :caching do
        include_context :caching_basic
        let(:content_tag) { FactoryBot.create(:content_tag) }
        def create_tagged_blog(title)
          FactoryBot.create(:blog, :published, title:).tap { |blog| BlogContentTag.create!(blog:, content_tag:) }
        end
        it "shows a new post in the full and the tagged feed" do
          create_tagged_blog("First post")
          get "/news.atom"
          get "/news.atom", params: {search_tags: content_tag.slug}
          expect(response.body).to include("First post")

          create_tagged_blog("Second post")
          get "/news.atom"
          expect(response.body).to include("Second post")
          # A tag search groups the blogs, which the whole-feed cache key can't follow
          get "/news.atom", params: {search_tags: content_tag.slug}
          expect(response.body).to include("Second post")
        end
      end
    end
  end
end
