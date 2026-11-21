require "rails_helper"

RSpec.describe LandingPagesController, type: :request do
  describe "#for_shops" do
    it "redirects to for_bike_shops_path" do
      expect(get("/for_shops")).to redirect_to(for_bike_shops_path)
    end
  end

  describe "/ucmerced" do
    it "redirects to registering with uc-merced" do
      expect(get("/ucmerced")).to redirect_to(new_register_path(organization_id: "uc-merced"))
    end
  end

  describe "#for_bike_shops" do
    it "starts the organization signup as a bike shop" do
      get "/for_bike_shops"
      expect(response.body).to match("<title>Bike Index for Bike Shops</title>")
      form = Capybara.string(response.body).find("form[action='/organizations/signup']")
      fields = form.all("[name^='organization_signup']", visible: :all).to_h { [it[:name], it[:value]] }
      expect(fields.keys).to match_array(%w[name email pos_kind kind].map { "organization_signup[#{it}]" })
      expect(fields["organization_signup[kind]"]).to eq "bike_shop"

      post "/organizations/signup", params: fields.merge("organization_signup[pos_kind]" => "ascend_pos")
      expect(response.status).to eq 422
      expect(Capybara.string(response.body)).to have_field("organization_signup[pos_kind]", type: :hidden, with: "ascend_pos")

      post "/organizations/signup", params: fields.merge("organization_signup[name]" => "Spoke Shop",
        "organization_signup[email]" => "shop@example.com", "organization_signup[pos_kind]" => "ascend_pos")
      expect(response).to redirect_to "/organizations/signup?step=2"
      expect(OrganizationSignup.last).to have_attributes(name: "Spoke Shop", kind: "bike_shop", email: "shop@example.com",
        pos_kind: "ascend_pos")
    end

    it "frames the checker on the visitor's place, and California without a location" do
      get "/for_bike_shops", headers: {"HTTP_CF_IPCOUNTRY" => "US", "HTTP_CF_REGION" => "Indiana"}
      expect(Capybara.string(response.body)).to have_css("iframe[src^='/ebike-rules/US/IN?']", visible: :all)

      get "/for_bike_shops"
      expect(Capybara.string(response.body)).to have_css("iframe[src^='/ebike-rules/US/CA?']", visible: :all)
    end
  end

  describe "#for_cities" do
    it "starts the checker on the visitor's state, and asks for one without a location" do
      get "/for_cities", headers: {"HTTP_CF_IPCOUNTRY" => "US", "HTTP_CF_REGION" => "Indiana"}
      expect(Capybara.string(response.body)).to have_field("state", type: :hidden, with: "US-IN")

      get "/for_cities"
      expect(Capybara.string(response.body)).to have_css("input[role=combobox][placeholder='Choose a state']")
        .and have_no_field("state", type: :hidden, with: /US-/)
    end

    # A bare CA or IN is Canada's or India's, so each option carries the US it belongs to
    it "sends a state the checker reads as a US state, not as a country with the same code" do
      get "/for_cities"
      expect(Capybara.string(response.body)).to have_css("option[value='US-CA']", text: "California (CA)", visible: :all)

      get "/ebike-rules", params: {state: "US-CA", manual: 1, top_speed: 28, throttle: 1}
      expect(response).to redirect_to("/ebike-rules/US/CA?manual=1&throttle=1&top_speed=28")
    end

    it "shows the registration flow's step 1 and the default course's first page, only once there's a course" do
      get "/for_cities"
      expect(Capybara.string(response.body)).to have_no_css("[inert]", visible: :all)

      FactoryBot.create(:education_course_default_active, :with_pages)
      get "/for_cities"
      phones = Capybara.string(response.body).all("[inert]", visible: :all)
      expect(phones.first).to have_field("propulsion_type_motorized", checked: true, visible: :all)
      expect(phones.last).to have_css("h2", text: "Safety check", visible: :all).and have_text("Step 1 of 3")
    end
  end

  describe "#for_advocacy" do
    it "redirects to for_community_groups_path" do
      expect(get("/for_advocacy")).to redirect_to(for_community_groups_path)
    end

    it "redirects the dashed spelling, keeping the query" do
      expect(get("/for-advocacy?utm_source=newsletter")).to redirect_to("/for_advocacy?utm_source=newsletter")
    end
  end

  {
    for_cities: "Bike Index for Cities",
    for_law_enforcement: "Bike Index for Law Enforcement",
    for_schools: "Bike Index for Schools",
    ambassadors_current: "Bike Index Ambassadors",
    ambassadors_how_to: "Become a Bike Index Ambassador",
    bike_shop_packages: "Bike Index for Bike Shops - Features and Pricing"
  }.each_pair do |controller_action, page_title|
    describe "##{controller_action}" do
      it "renders the correct template with the correct title" do
        get "/#{controller_action}"

        expect(response.status).to eq(200)
        expect(response).to render_template(controller_action)
        expect(response.body).to match("<title>#{page_title}</title>")
        expect(response.body).to match('<html lang="en">') # Accessibility
      end
    end
  end

  describe "#ascend" do
    it "renders the setup steps with the title" do
      get "/ascend"

      expect(response.status).to eq(200)
      expect(response.body).to match("<title>Ascend POS on Bike Index</title>")
      expect(response.body).to include("Create your shop account on Bike Index")
      expect(response.body).to_not include("Your shop is on Bike Index")
    end

    context "with a user in a shop" do
      include_context :request_spec_logged_in_as_organization_admin
      let(:current_organization) { FactoryBot.create(:organization, kind: "bike_shop") }

      it "marks the account step done" do
        get "/ascend"

        expect(response.status).to eq(200)
        expect(response.body).to include("Your shop is on Bike Index")
        expect(response.body).to_not include("Create shop account")
      end

      context "when the organization isn't a shop" do
        let(:current_organization) { FactoryBot.create(:organization, kind: "law_enforcement") }

        it "keeps the account step" do
          get "/ascend"

          expect(response.status).to eq(200)
          expect(response.body).to include("Create shop account")
          expect(response.body).to_not include("Your shop is on Bike Index")
        end
      end
    end
  end

  describe "#for_community_groups" do
    let!(:recovery_display) { FactoryBot.create(:recovery_display_with_photo, quote: "Recovered in under four hours") }

    it "renders the latest recovery stories" do
      get "/for_community_groups"

      expect(response.status).to eq(200)
      expect(response.body).to match("<title>Bike Index for Community Groups</title>")
      expect(response.body).to include("Recovered in under four hours")
      expect(response.body).to include('href="/organizations/signup/new?kind=bike_advocacy"')
    end
  end

  describe "welcome#index" do
    include_context :request_spec_logged_in_as_organization_user
    it "renders" do
      get "/"
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end

  describe "review app banner" do
    it "renders the banner, and suppresses it with NO_REVIEW_TOPBAR" do
      stub_const("ENV", ENV.to_hash.merge("REVIEW_APP" => "1"))
      get "/for_bike_shops"
      expect(response.body).to include("review-app-banner")

      stub_const("ENV", ENV.to_hash.merge("REVIEW_APP" => "1", "NO_REVIEW_TOPBAR" => "true"))
      get "/for_bike_shops"
      expect(response.body).not_to include("review-app-banner")
    end
  end

  describe "organization show" do
    let(:title) { response.body[/<title[^>]*>([^<]*)/, 1] }
    let!(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
    let!(:organization_landing_page) do
      FactoryBot.create(:organization_landing_page, organization:, body: "<p>Brakebills welcomes you</p>")
    end

    it "renders" do
      expect(LandingPageOrganizations::SLUGS).to include(organization.slug)
      get "/#{organization.slug}"
      expect(response.status).to eq(200)
      expect(response).to render_template("show")
      expect(title).to eq "Brakebills Bike Registration"
      expect(assigns(:page_id)).to eq "landing_pages_show"
      expect(response.body).to include "<p>Brakebills welcomes you</p>"
    end

    context "routed by the previous slug" do
      let!(:organization) { FactoryBot.create(:organization, short_name: "Brakebills University", previous_slug: "brakebills") }

      it "renders" do
        get "/brakebills"
        expect(response.status).to eq(200)
        expect(response.body).to include "<p>Brakebills welcomes you</p>"
      end
    end

    context "without a landing page" do
      let(:organization_landing_page) { nil }

      it "renders empty" do
        get "/#{organization.slug}"
        expect(response.status).to eq(200)
      end
    end

    context "xml request format" do
      it "renders (ignoring response format)" do
        get "/#{organization.slug}.xml"
        expect(response.status).to eq(200)
        expect(response).to render_template("show")
        expect(title).to eq "Brakebills Bike Registration"
      end
    end
  end
end
