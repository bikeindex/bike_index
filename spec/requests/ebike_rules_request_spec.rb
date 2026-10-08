# frozen_string_literal: true

require "rails_helper"

RSpec.describe EbikeRulesController, type: :request do
  describe "show" do
    # the response at hand, which an example's later requests replace
    def page = Capybara.string(response.body)
    let(:indiana) { {"HTTP_CF_IPCOUNTRY" => "US", "HTTP_CF_REGION" => "Indiana"} }

    def meta(property) = page.find("meta[property='#{property}'], meta[name='#{property}']", visible: :all)[:content]

    before { stub_bikebook_catalog }

    it "renders the lookup and every state's rules, with no state, and keeps it out of every cache" do
      get "/ebike-rules"

      expect(response).to have_http_status(:ok)
      expect(response.headers["Cache-Control"]).to eq "no-store"
      expect(page).to have_select("state", with_options: ["Select your state", "District of Columbia", "Wyoming"])
        .and have_no_css("#state option[selected]")
        .and have_css("form[action='/ebike-rules']")
        .and have_text("Location not shared")
        .and have_css("[data-ebike-rules--lookup-manifest-url-value='#{Integrations::Bikebook::Catalog::MANIFEST_URL}']")
        .and have_no_css("[role='status']")
        .and have_no_css("[role='alert']")
        .and have_title("E-bike rules", exact: true)
      # each state's page, and its rules rendered for search engines, collapsed
      expect(page).to have_link("Colorado", href: "/ebike-rules/co")
        .and have_css("#state-panel-co", text: "Class 3 riders must be 16 or older", visible: :all)
        .and have_css("#state-panel-wy", text: "We're compiling Wyoming's e-bike rules", visible: :all)
      expect(page.all("[data-ebike-rules--state-filter-target='state']").count).to eq 51
    end

    it "sends a request Cloudflare locates to its state's page, which no cache keeps" do
      get "/ebike-rules", params: {utm_source: "newsletter"}, headers: indiana

      expect(response).to redirect_to("/ebike-rules/in?utm_source=newsletter")
      expect(response).to have_http_status(:found)
      expect(response.headers["Cache-Control"]).to eq "no-store"

      follow_redirect!(headers: indiana)
      expect(page).to have_select("state", selected: "Indiana")
        .and have_text("We detected Indiana")
        .and have_no_css("[role='alert']")
    end

    it "renders a state's page with its own meta tags, whatever bike is checked on it" do
      get "/ebike-rules/co"

      expect(response).to have_http_status(:ok)
      expect(page).to have_select("state", selected: "Colorado")
        .and have_css("form[action='/ebike-rules/co']")
        .and have_no_css("[role='alert']")
        .and have_no_css("[role='status']")
        .and have_title("Colorado e-bike laws", exact: true)
      tags = %w[og:title twitter:title description og:description twitter:description og:url].map { meta(it) }
      expect(tags).to eq ["Colorado e-bike laws", "Colorado e-bike laws", *[meta("description")] * 3, "http://www.example.com/ebike-rules/co"]
      expect(meta("description")).to start_with("Colorado e-bike law: A vehicle with two or three wheels")
      expect(meta("description").length).to be <= 200
      expect(page.find("link[rel='canonical']", visible: :all)[:href]).to eq "http://www.example.com/ebike-rules/co"

      get "/ebike-rules/co", params: {bike: "m/specialized/2025/haul_st"}

      expect(page).to have_css("[role='status']",
        text: "Your Specialized Haul ST is legal to ride in Colorado as a Class 3 e-bike, with 1 rule to check.")
        .and have_css("[data-ebike-rules--lookup-display-value='Specialized Haul ST 2025']")
        .and have_link("View full Bike Book entry", href: "/bikebook?vehicle_models=m%2Fspecialized%2F2025%2Fhaul_st")
        .and have_title("Colorado e-bike laws", exact: true)
      expect(page.find("link[rel='canonical']", visible: :all)[:href]).to eq "http://www.example.com/ebike-rules/co"
      expect(meta("og:url")).to eq "http://www.example.com/ebike-rules/co"
    end

    it "describes a state the catalog has no law for, and says so on a check" do
      get "/ebike-rules/wy", params: {bike: "m/specialized/2025/haul_st"}

      expect(page).to have_title("Wyoming e-bike laws", exact: true)
      expect(meta("description")).to start_with("We're still reviewing Wyoming's e-bike law.")
      expect(page).to have_css("[role='status']", text: "We don't have Wyoming's e-bike rules on file yet.")
        .and have_text("We're still reviewing Wyoming's rules.")
    end

    it "keeps Alaska in review, as its e-bike law is for state parks rather than its roads" do
      get "/ebike-rules/ak", params: {bike: "m/specialized/2025/haul_st"}

      expect(page).to have_css("[role='status']", text: "We don't have Alaska's e-bike rules on file yet.")
      expect(meta("description")).to start_with("We're still reviewing Alaska's e-bike law.")
    end

    it "moves a state from the query, or in capitals, to its own page, and 404s one that isn't a state" do
      get "/ebike-rules", params: {state: "CO", bike: "m/specialized/2025/haul_st"}
      expect(response).to redirect_to("/ebike-rules/co?bike=m%2Fspecialized%2F2025%2Fhaul_st")
      expect(response).to have_http_status(:moved_permanently)

      get "/ebike-rules/ny", params: {state: "IN", bike: ""}
      expect(response).to redirect_to("/ebike-rules/in?bike=")

      get "/ebike-rules/CO"
      expect(response).to redirect_to("/ebike-rules/co")

      get "/ebike-rules/zz"
      expect(response).to have_http_status(:not_found)
    end

    it "checks a bike entered by hand" do
      get "/ebike-rules/co", params: {manual: "1", e_bike_class: "2", watts: "1000", throttle: "1"}

      expect(page).to have_css("[role='status']", text: "Your e-bike is not permitted as an e-bike under current Colorado rules.")
        .and have_css("[role='status'] li", text: "1,000W motor exceeds the 750W cap.")
        .and have_field("watts", with: "1000")
      expect(page.find("fieldset[data-ebike-rules--lookup-target='manualPanel']")[:disabled]).to be_nil
    end

    it "explains what's missing" do
      # a state left unchosen without JavaScript comes off the query, rather than being looked up
      get "/ebike-rules", params: {state: "", bike: ""}
      expect(response).to redirect_to("/ebike-rules?bike=")

      get "/ebike-rules", params: {bike: ""}, headers: indiana

      expect(page).to have_css("[role='alert']", text: "Choose a state.")
        .and have_css("[role='alert']", text: "Pick a bike from the list, or enter its details manually.")
        .and have_no_css("[role='status']")
      expect(page.find("fieldset[data-ebike-rules--lookup-target='manualPanel']", visible: :all)[:disabled]).to eq "disabled"

      get "/ebike-rules/co", params: {manual: "1", watts: ""}

      expect(page).to have_css("[role='alert']", text: "Enter the motor wattage.")
    end
  end
end
