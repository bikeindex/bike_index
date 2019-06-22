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
    bike_shop_packages: "Bike Index for Bike Shops - Features and Pricing",
    campus_packages: "Bike Index for Schools - Features and Pricing",
    cities_packages: "Bike Index for Cities - Features and Pricing",
  }.each_pair do |controller_action, page_title|
    describe "##{controller_action}" do
      it "renders the correct template with the correct title" do
        get "/#{controller_action}"

        expect(response.status).to eq(200)
        expect(response).to render_template(controller_action)
        expect(response.body).to match("<title>#{page_title}</title>")
      end
    end
  end

  describe "welcome#index" do
    include_context :request_spec_logged_in_as_organization_member
    it "renders" do
      get "/"
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end
end
