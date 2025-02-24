require "rails_helper"

RSpec.describe InfoController, type: :request do
  let(:base_url) { "/info" }
  describe "show" do
    let(:blog) do
      FactoryBot.create(:blog, info_kind: true, title: "Cool info about bike things", description_abbr: "Special info desc")
    end
    it "renders" do
      get "#{base_url}/#{blog.title_slug}"
      expect(response.status).to eq(200)
      expect(response).to render_template("show")
      # Test some header tag properties
      html_response = response.body
      # This is from header tag helpers
      expect(html_response).to match(/<title>Cool info about bike things</)
      # This is pulled from the translations file
      expect(html_response).to match(/<meta.*Special info desc/)
      expect(assigns(:page_id)).to eq "news_show"
    end
    context "blog" do
      let(:blog) { FactoryBot.create(:blog) }
      it "redirects" do
        get "#{base_url}/#{blog.title_slug}"
        expect(response).to redirect_to(news_path(blog.to_param))
      end
    end
  end

  describe "get_your_stolen_bike_back" do
    let!(:blog) { FactoryBot.create(:blog, title: "How to get your stolen bike back", info_kind: true) }
    it "renders" do
      get "/info/how-to-get-your-stolen-bike-back"
      expect(assigns(:blog)&.id).to eq blog.id
      expect(response.status).to eq(200)
    end
  end

  describe "static pages" do
    pages = %w[about protect_your_bike where serials image_resources resources security
      dev_and_design donate terms vendor_terms privacy lightspeed]
    context "no user" do
      pages.each do |page|
        context "#{page} with revised_layout enabled" do
          it "renders with revised_layout" do
            get "/#{page}"
            expect(response.status).to eq(200)
            expect(response).to render_template(page.to_sym)
            if page == "donate"
              expect(response).to render_template("layouts/payments_layout")
            else
              expect(response).to render_template("layouts/application")
            end
          end
        end
      end
    end
    context "signed in user" do
      # Since we're rendering things, and these are important pages,
      # let's test with users as well
      include_context :request_spec_logged_in_as_user
      pages.each do |page|
        context "#{page} with revised_layout enabled" do
          it "renders with revised_layout" do
            get "/#{page}"
            expect(response.status).to eq(200)
            expect(response).to render_template(page.to_sym)
            if page == "donate"
              expect(response).to render_template("layouts/payments_layout")
            else
              expect(response).to render_template("layouts/application")
            end
          end
        end
      end
    end
  end

  describe "support_the_index and support_bike_index" do
    it "redirects support_the_index" do
      get "/support_the_index"
      expect(response).to redirect_to donate_path
    end
    it "redirects support_the_index" do
      get "/support_bike_index"
      expect(response).to redirect_to donate_path
      get "/support_the_bike_index?amount="
      expect(response).to redirect_to donate_path
    end
    context "with amount param" do
      it "redirects to payments" do
        get "/support_bike_index?amount=12"
        expect(response).to redirect_to new_payment_path(amount: 12)
      end
    end
    context "why_donate" do
      it "redirects to why-donate" do
        get "/why_donate"
        expect(response).to redirect_to("/why-donate")
      end
    end
  end

  describe "why-donate" do
    let!(:blog) { FactoryBot.create(:blog, title: Blog.why_donate_slug) }
    it "renders the blog" do
      get "/why-donate"
      expect(response.code).to eq "200"
      expect(response).to render_template("news/show")
      expect(assigns(:blog)).to eq blog
    end
  end

  describe "user with stolen info" do
    include_context :request_spec_logged_in_as_user
    before do
      current_user.update_column :alert_slugs, ["promoted_alert_without_photo"]
    end
    it "renders with show alert" do
      get "/lightspeed"
      expect(response.code).to eq("200")
      expect(response).to render_template("lightspeed")
      expect(flash).to_not be_present
      expect(assigns(:show_general_alert)).to be_truthy
    end
    context "donate" do
      it "renders without show alert" do
        get "/donate"
        expect(response.code).to eq("200")
        expect(response).to render_template("donate")
        expect(flash).to_not be_present
        expect(assigns(:show_general_alert)).to be_falsey
      end
    end
  end

  describe "current_tsv" do
    it "redirects to current_tsv" do
      get "/how_not_to_buy_stolen"
      expect(response).to redirect_to InfoController::DONT_BUY_STOLEN_URL
    end
  end
end
