# frozen_string_literal: true

require "rails_helper"

RSpec.describe EbikeRulesController, type: :request do
  describe "show" do
    let(:page) { Capybara.string(response.body) }

    before { stub_bikebook_catalog }

    it "renders the lookup and every state's rules, with no result" do
      get "/ebike-rules"

      expect(response).to have_http_status(:ok)
      expect(page).to have_select("state", with_options: ["Select your state", "District of Columbia", "Wyoming"])
        .and have_no_css("#state option[selected]")
        .and have_text("Location not shared")
        .and have_css("[data-ebike-rules--lookup-manifest-url-value='#{BikebookController::MANIFEST_URL}']")
        .and have_no_css("[role='status']")
      # rendered for search engines, collapsed
      expect(page).to have_css("#state-panel-co", text: "Class 3 riders must be 16 or older", visible: :all)
        .and have_css("#state-panel-wy", text: "We're compiling Wyoming's e-bike rules", visible: :all)
      expect(page.all("[data-ebike-rules--state-filter-target='state']").count).to eq 51
    end

    it "picks the state Cloudflare locates the request in" do
      get "/ebike-rules", headers: {"HTTP_CF_IPCOUNTRY" => "US", "HTTP_CF_REGION" => "Indiana"}

      expect(page).to have_select("state", selected: "Indiana")
        .and have_text("We detected Indiana")
    end

    context "with a Bike Book model" do
      it "renders its verdict" do
        get "/ebike-rules", params: {state: "CO", bike: "m/specialized/2025/haul_st"}

        expect(page).to have_css("[role='status']",
          text: "Your Specialized Haul ST is legal to ride in Colorado as a Class 3 e-bike, with 1 rule to check.")
          .and have_select("state", selected: "Colorado")
          .and have_css("[data-ebike-rules--lookup-display-value='Specialized Haul ST 2025']")
          .and have_link("View full Bike Book entry", href: "/bikebook?vehicle_models=m%2Fspecialized%2F2025%2Fhaul_st")
      end

      it "says when the state's rules aren't on file" do
        get "/ebike-rules", params: {state: "WY", bike: "m/specialized/2025/haul_st"}

        expect(page).to have_css("[role='status']", text: "We don't have Wyoming's e-bike rules on file yet.")
          .and have_text("We're still reviewing Wyoming's rules.")
      end
    end

    it "checks a bike entered by hand" do
      get "/ebike-rules", params: {state: "CO", manual: "1", e_bike_class: "2", watts: "1000", throttle: "1"}

      expect(page).to have_css("[role='status']", text: "Your e-bike is not permitted as an e-bike under current Colorado rules.")
        .and have_css("[role='status'] li", text: "1,000W motor exceeds the 750W cap.")
        .and have_field("watts", with: "1000")
      expect(page.find("fieldset[data-ebike-rules--lookup-target='manualPanel']")[:disabled]).to be_nil
    end

    it "explains what's missing" do
      get "/ebike-rules", params: {state: "", bike: ""}

      expect(page).to have_css("[role='alert']", text: "Choose a state.")
        .and have_css("[role='alert']", text: "Pick a bike from the list, or enter its details manually.")
        .and have_no_css("[role='status']")
      expect(page.find("fieldset[data-ebike-rules--lookup-target='manualPanel']", visible: :all)[:disabled]).to eq "disabled"

      get "/ebike-rules", params: {state: "CO", manual: "1", watts: ""}

      expect(Capybara.string(response.body)).to have_css("[role='alert']", text: "Enter the motor wattage.")
    end
  end
end
