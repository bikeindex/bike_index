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
      expect(page).to have_css("input[role='combobox'][placeholder='Select your state']")
        .and have_css("[role='option']", text: "District of Columbia", visible: :all)
        .and have_css("[role='option']", text: "Wyoming", visible: :all)
        .and have_no_css("#state + * [data-hw-combobox-prefilled-display-value]")
        .and have_css("form[action='/ebike-rules']")
        .and have_text("Location not shared")
        .and have_css("[data-ebike-rules--lookup-manifest-url-value='#{Integrations::Bikebook::Catalog::MANIFEST_URL}']")
        .and have_no_css("[role='status']")
        .and have_no_css("[role='alert']")
        .and have_title("E-bike rules", exact: true)
      # each state's page, and its rules rendered for search engines, collapsed
      expect(page).to have_link("Check an e-bike in Colorado", href: "/ebike-rules/co#check", visible: :all)
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
      expect(page).to have_css("[data-hw-combobox-prefilled-display-value='Indiana (IN)']")
        .and have_text("We detected Indiana")
        .and have_no_css("[role='alert']")
    end

    it "renders a state's page with its own meta tags, whatever bike is checked on it" do
      get "/ebike-rules/co"

      expect(response).to have_http_status(:ok)
      expect(page).to have_css("[data-hw-combobox-prefilled-display-value='Colorado (CO)']")
        .and have_css("form[action='/ebike-rules/co']")
        .and have_no_css("[role='alert']")
        .and have_no_css("[role='status']")
        .and have_title("Colorado e-bike laws", exact: true)
      tags = %w[og:title twitter:title description og:description twitter:description og:url].map { meta(it) }
      expect(tags).to eq ["Colorado e-bike laws", "Colorado e-bike laws", *[meta("description")] * 3, "http://www.example.com/ebike-rules/co"]
      expect(meta("description")).to start_with("Colorado e-bike law: A vehicle with two or three wheels")
      expect(meta("description").length).to be <= 200
      expect(page.find("link[rel='canonical']", visible: :all)[:href]).to eq "http://www.example.com/ebike-rules/co"

      get "/ebike-rules/co", params: {vehicle_models: "m/specialized/2025/haul_st"}

      expect(page).to have_css("[role='status']",
        text: "Your Specialized Haul ST is legal to ride in Colorado as a Class 3 e-bike.")
        .and have_css("li", text: "Throttle stops at 20 mph")
        .and have_css("[data-ebike-rules--lookup-display-value='Specialized Haul ST 2025']")
        .and have_link("View full BikeBook entry", href: "/bikebook?vehicle_models=m%2Fspecialized%2F2025%2Fhaul_st")
        .and have_title("Colorado e-bike laws", exact: true)
      expect(page.find("link[rel='canonical']", visible: :all)[:href]).to eq "http://www.example.com/ebike-rules/co"
      expect(meta("og:url")).to eq "http://www.example.com/ebike-rules/co"
    end

    context "with the catalog failing", :caching do
      include_context :caching_basic
      include ActiveSupport::Testing::TimeHelpers

      it "asks it once a minute, however much of the page reads it" do
        requests = 0
        WebMock.stub_request(:get, "#{Integrations::Bikebook::Catalog::URL}manifest.json").to_return do
          requests += 1
          {status: 503}
        end

        2.times { get "/ebike-rules/ca", params: {vehicle_models: "m/specialized/2025/haul_st"} }

        expect(response).to have_http_status(:ok)
        expect(page).to have_css("[role='alert']", text: "Pick a bike from the list")
        expect(requests).to eq 1
      end

      it "doesn't keep the states list it didn't answer for" do
        WebMock.stub_request(:get, "#{Integrations::Bikebook::Catalog::URL}vocabulary.json")
          .to_return({status: 503}, {body: BikebookCatalogHelpers::FIXTURES.join("vocabulary.json").read})

        get "/ebike-rules/co"
        expect(page).to have_css("#state-panel-co", text: "We're compiling Colorado's e-bike rules", visible: :all)

        travel(61.seconds) { get "/ebike-rules/co" }
        expect(page).to have_css("#state-panel-co", text: "Class 3 riders must be 16 or older", visible: :all)
      end
    end

    it "describes a state the catalog has no law for, and says so on a check" do
      get "/ebike-rules/wy", params: {vehicle_models: "m/specialized/2025/haul_st"}

      expect(page).to have_title("Wyoming e-bike laws", exact: true)
      expect(meta("description")).to start_with("We're still reviewing Wyoming's e-bike law.")
      expect(page).to have_css("[role='status']", text: "We don't have Wyoming's e-bike rules on file yet.")
        .and have_text("We're still reviewing Wyoming's rules.")
    end

    it "checks a bike against Alaska's e-bike law" do
      get "/ebike-rules/ak", params: {vehicle_models: "m/specialized/2025/haul_st"}

      expect(page).to have_css("[role='status']", text: "Your Specialized Haul ST is legal to ride in Alaska")
      expect(page.find("#state-ak > h3")).to have_no_text("In review")
      expect(meta("description")).to_not include("still reviewing")
    end

    it "moves a state from the query, or in capitals, to its own page, and 404s one that isn't a state" do
      get "/ebike-rules", params: {state: "CO", vehicle_models: "m/specialized/2025/haul_st"}
      expect(response).to redirect_to("/ebike-rules/co?vehicle_models=m%2Fspecialized%2F2025%2Fhaul_st")
      expect(response).to have_http_status(:moved_permanently)

      get "/ebike-rules/ny", params: {state: "IN", vehicle_models: ""}
      expect(response).to redirect_to("/ebike-rules/in?vehicle_models=")

      get "/ebike-rules/CO"
      expect(response).to redirect_to("/ebike-rules/co")

      get "/ebike-rules/zz"
      expect(response).to have_http_status(:not_found)

      get "/ebike-rules", params: {state: ["ca"]}
      expect(response).to redirect_to("/ebike-rules")
    end

    it "checks a bike entered by hand" do
      get "/ebike-rules/co", params: {manual: "1", top_speed: "20", watts: "1000", throttle: "1"}

      expect(page).to have_css("[role='status']", text: "This isn't an e-bike under current Colorado rules.")
        .and have_css("[role='status'] li", text: "1,000W motor exceeds the 750W cap.")
        .and have_field("watts", with: "1000")
      expect(page.find("fieldset[data-ebike-rules--lookup-target='manualPanel']")[:disabled]).to be_nil
    end

    it "opens the manual panel in place of the bike field, with nothing checked yet" do
      get "/ebike-rules/co", params: {manual: "1"}

      expect(page).to have_no_css("[role='alert']")
        .and have_no_css("[role='status']")
      expect(page.find("[data-ebike-rules--lookup-target='bikeField']")[:class]).to include "tw:hidden"
      expect(page.find("[data-ebike-rules--lookup-target='closeManual']")[:class]).to_not include "tw:hidden"
      expect(page.find("fieldset[data-ebike-rules--lookup-target='manualPanel']")[:disabled]).to be_nil
    end

    it "classes a bike entered by hand by its top speed and throttle" do
      get "/ebike-rules/co", params: {manual: "1", top_speed: "20", watts: "250"}

      expect(page).to have_css("[role='status']", text: "Your e-bike is legal to ride in Colorado as a Class 1 e-bike.")
        .and have_checked_field("top_speed", with: "20")
        .and have_checked_field("throttle", with: "0")

      get "/ebike-rules/co", params: {manual: "1", top_speed: "28", watts: "250", throttle: "0"}
      expect(page).to have_css("[role='status']", text: "as a Class 3 e-bike")

      get "/ebike-rules/co", params: {manual: "1", top_speed: "29", watts: "250", throttle: "0"}
      expect(page).to have_css("[role='status']", text: "This isn't an e-bike under current Colorado rules.")
        .and have_css("[role='status'] li", text: "Assists past 28 mph, over the 28 mph limit.")
        .and have_text("Entered manually").and have_no_text("Entered manually · Class")
        .and have_css("dd", text: "Over 28 mph")
        .and have_text("Look for the UL mark on the frame label.")
        .and have_checked_field("top_speed", with: "29")
    end

    it "redirects /e-bike-rules, keeping the state and query" do
      get "/e-bike-rules"
      expect(response).to redirect_to("/ebike-rules")

      get "/e-bike-rules/co?manual=1&watts=250"
      expect(response).to redirect_to("/ebike-rules/co?manual=1&watts=250")
    end

    it "explains what's missing" do
      # a state left unchosen without JavaScript comes off the query, rather than being looked up
      get "/ebike-rules", params: {state: "", vehicle_models: ""}
      expect(response).to redirect_to("/ebike-rules?vehicle_models=")

      get "/ebike-rules", params: {vehicle_models: ""}, headers: indiana

      expect(page).to have_css("[role='alert']", text: "Choose a state.")
        .and have_css("[role='alert']", text: "Pick a bike from the list, or enter its details manually.")
        .and have_no_css("[role='status']")
      expect(page.find("fieldset[data-ebike-rules--lookup-target='manualPanel']", visible: :all)[:disabled]).to eq "disabled"

      # a manual check needs no wattage
      get "/ebike-rules/co", params: {manual: "1", top_speed: "20", watts: ""}

      expect(page).to have_css("[role='status']", text: "Your e-bike is legal to ride in Colorado as a Class 1 e-bike.")
        .and have_no_css("[role='alert']")
    end
  end
end
