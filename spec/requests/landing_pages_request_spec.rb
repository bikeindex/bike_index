require "rails_helper"

RSpec.describe LandingPagesController, type: :request do
  describe "#for_shops" do
    it "redirects to for_bike_shops_path" do
      expect(get("/for_shops")).to redirect_to(for_bike_shops_path)
    end
  end

  describe "#for_advocacy" do
    it "redirects to for_community_groups_path" do
      expect(get("/for_advocacy")).to redirect_to(for_community_groups_path)
    end
  end

  {
    for_bike_shops: "Bike Index for Bike Shops",
    for_cities: "Bike Index for Cities",
    for_community_groups: "Bike Index for Community Groups",
    for_law_enforcement: "Bike Index for Law Enforcement",
    for_schools: "Bike Index for Schools",
    ascend: "Ascend POS on Bike Index",
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
