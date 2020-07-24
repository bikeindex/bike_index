require "rails_helper"

RSpec.describe InfoController, type: :request do
  let(:base_url) { "/info" }
  describe "show" do
    let(:blog) do
      FactoryBot.create(:blog, is_info: true, title: "Cool info about bike things", description_abbr: "Special info desc")
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
    end
    context "blog" do
      let(:blog) { FactoryBot.create(:blog) }
      it "redirects" do
        get "#{base_url}/#{blog.title_slug}"
        expect(response).to redirect_to(news_path(blog.to_param))
      end
    end
  end

  describe "static pages" do
    pages = %w[about protect_your_bike where serials image_resources resources
      dev_and_design support_bike_index terms vendor_terms privacy lightspeed]
    context "no user" do
      pages.each do |page|
        context "#{page} with revised_layout enabled" do
          it "renders with revised_layout" do
            get "/#{page}"
            expect(response.status).to eq(200)
            expect(response).to render_template(page.to_sym)
            if page == "support_bike_index"
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
            if page == "support_bike_index"
              expect(response).to render_template("layouts/payments_layout")
            else
              expect(response).to render_template("layouts/application")
            end
          end
        end
      end
    end
  end

  describe "user with stolen info" do
    include_context :request_spec_logged_in_as_user
    before do
      current_user.update_column :general_alerts, ["theft_alert_without_photo"]
    end
    it "renders with show alert" do
      get "/lightspeed"
      expect(response.code).to eq("200")
      expect(response).to render_template("lightspeed")
      expect(flash).to_not be_present
      expect(assigns(:show_general_alert)).to be_truthy
    end
    context "support_bike_index" do
      it "renders without show alert" do
        get "/support_bike_index"
        expect(response.code).to eq("200")
        expect(response).to render_template("support_bike_index")
        expect(flash).to_not be_present
        expect(assigns(:show_general_alert)).to be_falsey
      end
    end
  end
end
