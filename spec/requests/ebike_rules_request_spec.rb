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
        .and have_css("form[action='/ebike-rules']")
        .and have_css("[data-inline-note]", text: "Choose your state from the list.")
        .and have_css("[data-ebike-rules--lookup-manifest-url-value='#{Integrations::Bikebook::Catalog::MANIFEST_URL}']")
        .and have_no_css("[role='status']")
        .and have_no_css("[role='alert']")
        .and have_title("E-bike rules", exact: true)
      expect(page.find("[data-ebike-rules--lookup-target='state'] .hw-combobox")["data-hw-combobox-prefilled-display-value"]).to be_nil
      # each state's page, and its rules rendered for search engines, collapsed
      expect(page).to have_link("Check an e-bike in Colorado", href: "/ebike-rules/US/CO#check", visible: :all)
        .and have_css("#state-panel-co", text: "Class 3 riders must be 16 or older", visible: :all)
        .and have_css("#state-panel-wy", text: "We're compiling Wyoming's e-bike rules", visible: :all)
      expect(page.all("[data-ebike-rules--state-filter-target='state']").count).to eq 51
      # a state whose law isn't the three classes says which it covers in its row, where it shows collapsed
      expect(%w[ny nj pa ca wy].map { page.find("#state-#{it} > h3").text.squish })
        .to eq ["New York Classes 1 & 2 only", "New Jersey Class 1 only", "Pennsylvania Not 3 classes", "California", "Wyoming In review"]
    end

    it "renders the classes frame alone: a state's own classes where it doesn't use the three, and the three without a state" do
      frame = {"Turbo-Frame" => Pages::EbikeRules::Classes::Component::FRAME_ID}
      get "/ebike-rules/US/NJ", headers: frame

      expect(page).to have_css("turbo-frame#ebike-rules-classes h2", text: "New Jersey e-bike classes")
        .and have_css("h3", text: "Low-Speed Electric Bicycle")
        .and have_css("h3", text: "Not an e-bike")
        .and have_no_css("h3", text: "Dirt Bike")
        .and have_no_css("h3", text: "Class 1")
        .and have_no_css("#ebike-rules-check")

      # rather than a located visitor's state
      get "/ebike-rules", headers: frame.merge(indiana)
      expect(response).to have_http_status(:ok)
      expect(page).to have_css("h2", text: "E-bike classes, explained").and have_css("h3", text: "Class 1")
        .and have_text("Often comes with a helmet rule").and have_text("Most states treat these as mopeds or motorcycles")

      # a three-class state's own Class 3 limits, and what its motorcycle needs, in place of most states'
      get "/ebike-rules/US/CA", headers: frame
      expect(page).to have_css("h3", text: "Class 3").and have_css("[role=button]", text: "California specifics")
        .and have_css("li", text: "Riders must be 16 or older to ride a Class 3")
        .and have_css("li", text: /Class 3 can.t be sold to anyone under 16 California Vehicle Code §§21212\.5, 21213 1 2 3/, normalize_ws: true)
        .and have_css("li", text: "Registered and plated with the DMV, and must carry liability insurance")
        .and have_no_css("li", text: "Allowed on freeways")
        .and have_no_text("Often comes with a helmet rule")
        .and have_no_text("Most states treat these")
    end

    it "renders one card alone in the frame asked for: a class's with its state's rules, any classification's, else the e-moto's" do
      frame = ->(suffix) { {"Turbo-Frame" => "#{Pages::EbikeRules::ClassCard::Component::FRAME_ID}-#{suffix}"} }
      get "/ebike-rules/US/CA", params: {e_bike_class: 3}, headers: frame.call(3)
      expect(page).to have_css("turbo-frame#ebike-rules-class-card-3 h3", text: "Class 3")
        .and have_css("[role=button]", text: "California specifics")
        .and have_css("li", text: "Riders must be 16 or older to ride a Class 3")
        .and have_no_css("h3", text: "Class 1").and have_no_css("#ebike-rules-classes")

      get "/ebike-rules/US/CA", params: {e_bike_class: "12"}, headers: frame.call("emoto")
      expect(page).to have_css("turbo-frame#ebike-rules-class-card-emoto h3", text: "Not an e-bike")
        .and have_css("li", text: "Registered and plated with the DMV, and must carry liability insurance")

      get "/ebike-rules", params: {classification: "evc/moped"}, headers: frame.call("evc-moped")
      expect(page).to have_css("turbo-frame#ebike-rules-class-card-evc-moped h3", text: "Moped, up to 2 hp and 30 mph")
        .and have_text("30 mph").and have_no_css("[role=img]")

      # one the state's law folds into the e-moto, as its classes do
      get "/ebike-rules/US/NJ", params: {classification: "evc/us/nj/dirt_bike"}, headers: frame.call("evc-us-nj-dirt_bike")
      expect(page).to have_css("turbo-frame#ebike-rules-class-card-evc-us-nj-dirt_bike h3", text: "Not an e-bike")
      # as is the catalog's marker for one out of class, in a state whose law bars a Class 3's throttle, but no other
      get "/ebike-rules", params: {classification: "evc/out_of_class/us/ca"}, headers: frame.call("evc-out_of_class-us-ca")
      expect(page).to have_css("turbo-frame#ebike-rules-class-card-evc-out_of_class-us-ca h3", text: "Not an e-bike")
      get "/ebike-rules", params: {classification: "evc/out_of_class/us/co"}, headers: frame.call("evc-out_of_class-us-co")
      expect(response).to have_http_status(:not_found)

      get "/ebike-rules", params: {classification: "evc/nothing"}, headers: frame.call("evc-nothing")
      expect(response).to have_http_status(:not_found)
    end

    it "sends a request Cloudflare locates to its state's page, which no cache keeps" do
      get "/ebike-rules", params: {utm_source: "newsletter"}, headers: indiana

      expect(response).to redirect_to("/ebike-rules/US/IN?utm_source=newsletter")
      expect(response).to have_http_status(:found)
      expect(response.headers["Cache-Control"]).to eq "no-store"

      follow_redirect!(headers: indiana)
      expect(page).to have_css("[data-hw-combobox-prefilled-display-value='Indiana (IN)']")
        .and have_text("We detected Indiana.")
        .and have_no_css("[role='alert']")

      # a bike comes along, as from BikeBook's link, to be checked there
      get "/ebike-rules", params: {vehicle_models: "m/specialized/2025/haul_st"}, headers: indiana
      expect(response).to redirect_to("/ebike-rules/US/IN?vehicle_models=m/specialized/2025/haul_st")

      # but a frame's check waits for the place the form hasn't chosen
      get "/ebike-rules", params: {vehicle_models: "m/specialized/2025/haul_st"}, headers: indiana.merge("Turbo-Frame" => "ebike-rules-check")
      expect(response).to have_http_status(:ok)
    end

    it "renders a state's page with its own meta tags, whatever bike is checked on it" do
      get "/ebike-rules/US/CO"

      expect(response).to have_http_status(:ok)
      expect(page).to have_css("[data-hw-combobox-prefilled-display-value='Colorado (CO)']")
        .and have_css("form[action='/ebike-rules/US/CO']")
        .and have_no_css("[role='alert']")
        .and have_no_css("[role='status']")
        .and have_title("Colorado e-bike laws", exact: true)
      tags = %w[og:title twitter:title description og:description twitter:description og:url].map { meta(it) }
      expect(tags).to eq ["Colorado e-bike laws", "Colorado e-bike laws", *[meta("description")] * 3, "http://www.example.com/ebike-rules/US/CO"]
      expect(meta("description")).to start_with("Colorado e-bike law: A vehicle with two or three wheels")
      expect(meta("description").length).to be <= 200
      expect(page.find("link[rel='canonical']", visible: :all)[:href]).to eq "http://www.example.com/ebike-rules/US/CO"

      get "/ebike-rules/US/CO", params: {vehicle_models: "m/specialized/2025/haul_st"}

      expect(page).to have_css("[role='status']",
        text: "Your Specialized Haul ST is legal to ride in Colorado as a Class 3 e-bike, and as Class 2 with its optional throttle.")
        .and have_css("li", text: "Classes 2 and 3 are recognized")
        .and have_css("li", text: "Optional throttle stops at 20 mph")
        .and have_css("dd", text: "Optional, to 20")
        .and have_css("[data-ebike-rules--lookup-display-value='Specialized Haul ST 2025']")
        .and have_link("View full BikeBook entry", href: "/bikebook?vehicle_models=m/specialized/2025/haul_st&view=motors")
        .and have_title("Colorado e-bike laws", exact: true)
      # each class's tile a tooltip of its US class card, in order, the optional throttle's captioned
      tiles = page.all("[data-controller~='ui--tooltip']:has(> button [role='img'])")
      expect(tiles.map { it.find("> button [role='img']")[:"aria-label"] }).to eq(["Class 2 e-bike", "Class 3 e-bike"])
      expect(tiles.map { it.find("[role='tooltip'] h3", visible: :all).text(:all).strip }).to eq(["Class 2", "Class 3"])
      # ending in its catalog ID, a copy away
      expect(tiles.map { it.find("[role='tooltip'] code", visible: :all).text(:all).strip }).to eq(["evc/us/class_2", "evc/us/class_3"])
      expect(tiles.first).to have_css("[role='tooltip'] button[title='Copy ID']", visible: :all)
      expect(page).to have_css("div:has(> [data-controller~='ui--tooltip'] [aria-label='Class 2 e-bike']) > span", text: "w/ optional throttle")
      expect(page.find("link[rel='canonical']", visible: :all)[:href]).to eq "http://www.example.com/ebike-rules/US/CO"
      expect(meta("og:url")).to eq "http://www.example.com/ebike-rules/US/CO"
    end

    it "marks a check's log line for LogSearcher, and not a page view's or a redirect's" do
      marks = []
      ActiveSupport::Notifications.subscribed(->(event) { marks << event.payload[:logged_search] }, "process_action.action_controller") do
        get "/ebike-rules/US/CO"
        get "/ebike-rules", params: {state: "CO", vehicle_models: "m/specialized/2025/haul_st"}
        get "/ebike-rules/US/CO", params: {vehicle_models: "m/specialized/2025/haul_st"}
        get "/ebike-rules/US/CO", params: {manual: "1", top_speed: "20"}, headers: {"Turbo-Frame" => "ebike-rules-check"}
      end
      expect(marks).to eq [nil, nil, true, true]
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

        2.times { get "/ebike-rules/US/CA", params: {vehicle_models: "m/specialized/2025/haul_st"} }

        expect(response).to have_http_status(:ok)
        expect(page).to have_css("[role='alert']", text: "Pick a bike from the list")
        expect(requests).to eq 1
      end

      it "doesn't keep the states list it didn't answer for" do
        WebMock.stub_request(:get, "#{Integrations::Bikebook::Catalog::URL}vocabulary.json")
          .to_return({status: 503}, {body: BikebookCatalogHelpers::FIXTURES.join("vocabulary.json").read})

        get "/ebike-rules/US/CO"
        expect(page).to have_css("#state-panel-co", text: "We're compiling Colorado's e-bike rules", visible: :all)

        travel(61.seconds) { get "/ebike-rules/US/CO" }
        expect(page).to have_css("#state-panel-co", text: "Class 3 riders must be 16 or older", visible: :all)
      end
    end

    it "describes a state the catalog has no law for, and says so on a check" do
      get "/ebike-rules/US/WY", params: {vehicle_models: "m/specialized/2025/haul_st"}

      expect(page).to have_title("Wyoming e-bike laws", exact: true)
      expect(meta("description")).to start_with("We're still reviewing Wyoming's e-bike law.")
      expect(page).to have_css("[role='status']", text: "We don't have Wyoming's e-bike rules on file yet.")
        .and have_text("We're still reviewing Wyoming's rules.")
    end

    it "checks a bike against Alaska's e-bike law" do
      get "/ebike-rules/US/AK", params: {vehicle_models: "m/specialized/2025/haul_st"}

      expect(page).to have_css("[role='status']", text: "Your Specialized Haul ST is legal to ride in Alaska")
      expect(page.find("#state-ak > h3")).to have_no_text("In review")
      expect(meta("description")).to_not include("still reviewing")
    end

    it "checks a Class 3 with a stock throttle as out of class in California alone" do
      get "/ebike-rules/US/CA", params: {vehicle_models: "m/aventon/2026/level_4_adv"}

      expect(page).to have_css("[role='status']", text: "Your Aventón Level 4 ADV is not permitted as an e-bike under current California rules.")
      expect(page.all("[role='status'] li").map(&:text)).to eq ["It is a Class 2 and Class 3 e-bike, which is not permitted.",
        "It may be regulated as a moped or motor vehicle instead, which can require registration and a license."]
      # its speed and throttle fail too, which the classes' note already gives as the reason
      speed = page.find("li", text: /Top assisted speed\s*28\W*mph\s*Assists to 28\W*mph, not allowed with a throttle/)
      throttle = page.find("li", text: /Throttle\s*Allowed\s*Not allowed with Class 3 assist/)
      [speed, throttle].each { expect(it).to have_css("[role='img'][aria-label='Does not meet this rule']") }

      get "/ebike-rules/US/CO", params: {vehicle_models: "m/aventon/2026/level_4_adv"}
      expect(page).to have_css("[role='status']", text: "Your Aventón Level 4 ADV is legal to ride in Colorado as a Class 2 and 3 e-bike")

      # as is one entered by hand, which is both classes as such a model is
      get "/ebike-rules/US/CA", params: {manual: "1", top_speed: "28", throttle: "1"}
      expect(page).to have_css("[role='status'] li", text: "It is a Class 2 and Class 3 e-bike, which is not permitted.")
      # under the e-moto's tile rather than its classes', with California's out of class ID
      expect(page.all("section[aria-live] [data-controller~='ui--tooltip'] > button[aria-label$='e-bike']").map { it[:"aria-label"] }).to eq ["E-moto, not an e-bike"]
      expect(page.find("section[aria-live] [role='tooltip'] code", visible: :all).text(:all).strip).to eq "evc/out_of_class/us/ca"

      # a throttle sold separately isn't the bike's as sold, but an option, which would put it in no class: its Class 3
      # tile, then the e-moto's captioned with the throttle
      get "/ebike-rules/US/CA", params: {vehicle_models: "m/specialized/2025/haul_st"}
      expect(page).to have_css("[role='status']", text: "Your Specialized Haul ST is legal to ride in California as a Class 3 e-bike, without its optional throttle.")
        .and have_no_css("[role='status'] li")
        .and have_css("li", text: /Throttle\s*Allowed\s*It's legal only without its optional throttle/)
      expect(page.all("section[aria-live] [data-controller~='ui--tooltip'] > button[aria-label$='e-bike']").map { it[:"aria-label"] })
        .to eq ["Class 3 e-bike", "E-moto, not an e-bike"]
      expect(page).to have_css("section[aria-live] div:has(> [data-controller~='ui--tooltip'] [aria-label='E-moto, not an e-bike']) > span", text: "w/ optional throttle")
      expect(page.all("section[aria-live] [role='tooltip'] code", visible: :all).map { it.text(:all).strip }).to eq ["evc/us/class_3", "evc/out_of_class/us/ca"]
    end

    it "moves a place from the query, or a state's old path, to its own page, and 404s one that isn't a place" do
      get "/ebike-rules", params: {state: "US-CO", vehicle_models: "m/specialized/2025/haul_st"}
      expect(response).to redirect_to("/ebike-rules/US/CO?vehicle_models=m/specialized/2025/haul_st")
      expect(response).to have_http_status(:moved_permanently)

      get "/ebike-rules/US/NY", params: {state: "IN", vehicle_models: ""}
      expect(response).to redirect_to("/ebike-rules/US/IN?vehicle_models=")

      get "/ebike-rules", params: {country: "CA"}
      expect(response).to redirect_to("/ebike-rules/CA")

      # a state's lowercase abbreviation, as its page's path was, even where it's a country's code too
      get "/ebike-rules/ca"
      expect(response).to redirect_to("/ebike-rules/US/CA")
      expect(response).to have_http_status(:moved_permanently)

      # in capitals, a state's where no place has it
      get "/ebike-rules/CO"
      expect(response).to redirect_to("/ebike-rules/US/CO")

      get "/ebike-rules/us/co"
      expect(response).to redirect_to("/ebike-rules/US/CO")

      get "/ebike-rules/ca/nb"
      expect(response).to redirect_to("/ebike-rules/CA/NB")

      get "/ebike-rules/CA"
      expect(response).to have_http_status(:ok)

      get "/ebike-rules/zz"
      expect(response).to have_http_status(:not_found)

      get "/ebike-rules/US/ZZ"
      expect(response).to have_http_status(:not_found)

      get "/ebike-rules", params: {state: ["ca"]}
      expect(response).to redirect_to("/ebike-rules")
    end

    it "renders Canada's page: a province to pick, its federal law in km/h, and nothing of the US" do
      get "/ebike-rules/CA", params: {vehicle_models: "m/specialized/2025/haul_st_ca"}

      expect(response).to have_http_status(:ok)
      expect(page).to have_title("Canada e-bike laws", exact: true)
        .and have_css("input[role='combobox'][placeholder='Select your province or territory']")
        .and have_css("[data-ebike-rules--lookup-target='state'] [role='option']", text: "Ontario (ON)", visible: :all)
        .and have_css("[data-ebike-rules--lookup-target='state'] [role='option'][data-value='CA-ON']", visible: :all)
        .and have_no_css("[data-ebike-rules--lookup-target='state'] [role='option']", text: "Colorado", visible: :all)
        .and have_css("form[action='/ebike-rules/CA'][data-ebike-rules--lookup-country-path-value='/ebike-rules/CA']")
        # with a bike and no province, there's nothing to check it against
        .and have_css("[role='alert']", text: "Choose a province or territory.")
        .and have_no_css("[role='status']")
        .and have_text("Not in Canada?")
        .and have_css("label", text: "32 km/h").and have_css("label", text: "Over 32 km/h")
        .and have_css("#ebike-rules-classes h2", text: "E-bike laws in Canada")
        .and have_css("#ebike-rules-classes h3", text: "Canadian Power-Assisted Bicycle")
        .and have_css("h2", text: "E-bike laws by province and territory")
        .and have_link("Check an e-bike in Ontario", href: "/ebike-rules/CA/ON#check", visible: :all)
        .and have_css("#state-panel-ca-nb h3", text: "Motor Driven Cycle", visible: :all)
        .and have_text("Provincial and territorial law summaries")
      # but the country switch's way back to it
      expect(page.find("main").text.remove("United States (US)")).not_to match(/\b(US|U\.S\.|mph|states?|DMV|Class [123])\b/)
      # BikeBook's models sold in Canada
      expect(response.body).to include("/bikebook?electric=1&amp;market=CA")
      expect(page.all("[data-ebike-rules--state-filter-target='state']").count).to eq 2
      expect(meta("description")).to start_with("Canada e-bike law:")
      expect(page.find("link[rel='canonical']", visible: :all)[:href]).to eq "http://www.example.com/ebike-rules/CA"
      # the country switch lists the US and the other places, and the province picker Canada's provinces
      expect(page).to have_css("#ebike-rules-switch-country [role='option']", text: "United States (US)", visible: :all)
        .and have_css("#ebike-rules-switch-country [role='option']", text: "European Union (EU)", visible: :all)
        .and have_no_css("#ebike-rules-switch-country [role='option']", text: "Ontario", visible: :all)

      # without a bike, a prompt to pick one
      get "/ebike-rules/CA"
      expect(page).to have_css("[data-inline-note]", text: "Choose your province or territory from the list.")
    end

    it "checks a bike against a province's law, in km/h" do
      get "/ebike-rules/CA/ON", params: {vehicle_models: "m/specialized/2025/haul_st_ca"}

      expect(page).to have_title("Ontario e-bike laws", exact: true)
        .and have_css("[data-hw-combobox-prefilled-display-value='Ontario (ON)']")
        .and have_css("[role='status']", text: "Your Specialized Haul ST is legal to ride in Ontario under the Power-Assisted Bicycle rules.")
        .and have_css("li", text: /Top assisted speed\s*32 km\/h\s*Assists to 32 km\/h, within the limit/)
        .and have_css("dd", text: "Optional, to 32 km/h")
        .and have_checked_field("top_speed", with: "32")
        .and have_field("watts", with: "500")
        .and have_no_css("[role='img'][aria-label^='Class']")
      expect(page.find("main").text.remove("United States (US)")).not_to match(/\b(US|mph|states?|Class [123])\b/)

      get "/ebike-rules/CA/ON", params: {manual: "1", top_speed: "33", watts: "750", throttle: "1"}
      expect(page).to have_css("[role='status']", text: "This isn't an e-bike under current Ontario rules.")
        .and have_css("[role='status'] li", text: "750W motor exceeds the 500W cap.")
        .and have_css("[role='status'] li", text: "Assists past 32 km/h, over the 32 km/h limit.")
        .and have_css("dd", text: "Over 32 km/h")
        .and have_checked_field("top_speed", with: "33")

      # a province with no e-bike law of its own checks it as the motor vehicle an e-bike falls in with there
      get "/ebike-rules/CA/NB", params: {manual: "1", top_speed: "32", watts: "500", throttle: "0"}
      expect(page).to have_css("[role='status']", text: "Your e-bike may be legal to ride in New Brunswick under the Motor Driven Cycle rules")
        .and have_css("li", text: "Registered with one plate", visible: :all)
    end

    it "renders a place outside the countries it checks: its law and other classes, in km/h, with no bike check" do
      get "/ebike-rules/EU", params: {vehicle_models: "m/specialized/2025/haul_st"}

      expect(response).to have_http_status(:ok)
      expect(page).to have_title("European Union e-bike laws", exact: true)
        .and have_css("[data-hw-combobox-prefilled-display-value='European Union (EU)']")
        .and have_no_css("[role='status']")
        .and have_text("Bike checks cover US states and Canadian provinces for now. European Union's e-bike laws are below.")
        .and have_css("#ebike-rules-classes h2", text: "E-bike laws in European Union")
        .and have_css("#ebike-rules-classes dd", text: "25 km/h")
      # the country switch lists the places outside the US, and the state picker the states alone with this one
      expect(page).to have_css("#ebike-rules-switch-country [role='option']", text: "Canada (CA)", visible: :all)
        .and have_no_css("#ebike-rules-switch-country [role='option']", text: "Colorado", visible: :all)
        .and have_css("#ebike-rules-switch-country [role='option'][data-value='CA-ON']", text: "Ontario (CA-ON)", visible: :all)
        .and have_css("[data-ebike-rules--lookup-target='state'] [role='option'][data-value='US-CO']", text: "Colorado (CO)", visible: :all)
    end

    it "sends a visitor Cloudflare locates outside the US to their place's page, a region's or else its country's" do
      ontario = {"HTTP_CF_IPCOUNTRY" => "CA", "HTTP_CF_REGION" => "Ontario"}
      get "/ebike-rules", headers: ontario
      expect(response).to redirect_to("/ebike-rules/CA/ON")

      follow_redirect!(headers: ontario)
      expect(page).to have_text("We detected Ontario.")

      get "/ebike-rules", headers: {"HTTP_CF_IPCOUNTRY" => "CA", "HTTP_CF_REGION" => "Quebec"}
      expect(response).to redirect_to("/ebike-rules/CA")

      # unless they chose the US
      get "/ebike-rules", params: {country: "US"}, headers: ontario
      expect(response).to redirect_to("/ebike-rules/US")
      follow_redirect!(headers: ontario)
      expect(response).to have_http_status(:ok)
      expect(page).to have_css("input[role='combobox'][placeholder='Select your state']")
        .and have_css("form[action='/ebike-rules']")
      expect(page.find("link[rel='canonical']", visible: :all)[:href]).to eq "http://www.example.com/ebike-rules"

      # where a US visitor is sent to their state
      get "/ebike-rules/US", headers: indiana
      expect(response).to redirect_to("/ebike-rules/US/IN")
    end

    it "checks a bike entered by hand" do
      get "/ebike-rules/US/CO", params: {manual: "1", top_speed: "20", watts: "1000", throttle: "1"}

      expect(page).to have_css("[role='status']", text: "This isn't an e-bike under current Colorado rules.")
        .and have_css("[role='status'] li", text: "1,000W motor exceeds the 750W cap.")
        .and have_field("watts", with: "1000")
      expect(page.find("form[data-details]")["data-details"]).to eq "manual"
    end

    it "shows the bike's details beside its model, with nothing checked or chosen yet" do
      get "/ebike-rules/US/CO", params: {manual: "1"}

      expect(page).to have_no_css("[role='alert']")
        .and have_no_css("[role='status']")
        .and have_field("vehicle_models", disabled: true)
        .and have_no_checked_field("top_speed")
        .and have_no_checked_field("throttle")
        .and have_css("legend", text: "Your bike's details")
      expect(page.find("form[data-details]")["data-details"]).to eq "manual"
    end

    it "fills the details from a picked model, and checks the details changed from it, keeping the model" do
      get "/ebike-rules/US/CO", params: {vehicle_models: "m/specialized/2025/haul_st"}

      expect(page).to have_css("[role='status']", text: "Your Specialized Haul ST is legal to ride in Colorado")
        .and have_checked_field("top_speed", with: "28")
        .and have_checked_field("throttle", with: "1")
        .and have_field("watts", with: "700")
        .and have_css("legend", text: "Specialized Haul ST details")
      expect(page.find("form[data-details]")["data-details"]).to eq "model"
      # its id alone is the check
      expect(page.find("input[name='manual']", visible: :all)[:disabled]).to eq "disabled"
      expect(page.find("[data-bike-details]", visible: :all)["data-bike-details"]).to eq({top_speed: 28, throttle: 1, watts: 700}.to_json)

      get "/ebike-rules/US/CO", params: {vehicle_models: "m/specialized/2025/haul_st", manual: "1", top_speed: "28", throttle: "1", watts: "1000"}
      expect(page).to have_css("[role='status']", text: "This isn't an e-bike under current Colorado rules.")
        .and have_field("watts", with: "1000")
        .and have_css("legend span.tw\\:hidden", text: "Custom details")
        .and have_css("legend", text: "Specialized Haul ST details")
      expect(page.find("form[data-details]")["data-details"]).to eq "custom"
      expect(page.find("form[data-details]")["data-ebike-rules--lookup-display-value"]).to eq "Specialized Haul ST 2025"
      expect(page.find("input[name='manual']", visible: :all)[:disabled]).to be_nil
    end

    it "classes a bike entered by hand by its top speed and throttle" do
      get "/ebike-rules/US/CO", params: {manual: "1", top_speed: "20", watts: "250"}

      expect(page).to have_css("[role='status']", text: "Your e-bike is legal to ride in Colorado as a Class 1 e-bike.")
        .and have_checked_field("top_speed", with: "20")
        .and have_checked_field("throttle", with: "0")

      get "/ebike-rules/US/CO", params: {manual: "1", top_speed: "28", watts: "250", throttle: "0"}
      expect(page).to have_css("[role='status']", text: "as a Class 3 e-bike")

      get "/ebike-rules/US/CO", params: {manual: "1", top_speed: "29", watts: "250", throttle: "0"}
      expect(page).to have_css("[role='status']", text: "This isn't an e-bike under current Colorado rules.")
        .and have_css("[role='status'] li", text: "Assists past 28 mph, over the 28 mph limit.")
        .and have_text("Entered manually").and have_no_text("Entered manually · Class")
        .and have_css("dd", text: "Over 28 mph")
        .and have_text("Look for the UL mark on the frame and battery labels.")
        .and have_checked_field("top_speed", with: "29")
    end

    it "fills a model's details from what its record has: its peak power without a rating, its class without a speed" do
      block = JSON.parse(BikebookCatalogHelpers::FIXTURES.join("models/aventon/2026.json").read)
      block["models"]["m/aventon/2026/level_4_adv"]["motors"].each { it["operating_modes"].each { it.delete("max_speed") } }
      WebMock.stub_request(:get, "#{Integrations::Bikebook::Catalog::URL}models/aventon/2026.json").to_return(body: block.to_json)

      get "/ebike-rules/US/CO", params: {vehicle_models: "m/aventon/2026/level_4_adv"}
      expect(page).to have_checked_field("top_speed", with: "28").and have_field("watts", with: "750")

      # a speed over 28 mph, and peak power, for a vehicle the catalog rates no motor of
      get "/ebike-rules/US/CO", params: {vehicle_models: "m/sur_ron/2026/ultra_bee_hp_x_us"}
      expect(page).to have_checked_field("top_speed", with: "29")
        .and have_checked_field("throttle", with: "1")
        .and have_field("watts", with: "24500")
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

      # on a checked country's page, it waits for one there
      get "/ebike-rules/CA/ON", params: {state: "", vehicle_models: ""}
      expect(response).to redirect_to("/ebike-rules/CA?vehicle_models=")
      get "/ebike-rules/US", params: {state: "", vehicle_models: ""}
      expect(response).to redirect_to("/ebike-rules/US?vehicle_models=")
      get "/ebike-rules/EU", params: {state: "", vehicle_models: ""}
      expect(response).to redirect_to("/ebike-rules?vehicle_models=")

      get "/ebike-rules/CA", params: {vehicle_models: ""}
      expect(page).to have_css("[role='alert']", text: "Choose a province or territory.")

      get "/ebike-rules", params: {vehicle_models: ""}

      expect(page).to have_css("[role='alert']", text: "Choose a state.")
        .and have_css("[role='alert']", text: "Pick a bike from the list, or enter its details manually.")
        .and have_no_css("[role='status']")

      # a manual check needs no wattage
      get "/ebike-rules/US/CO", params: {manual: "1", top_speed: "20", watts: ""}

      expect(page).to have_css("[role='status']", text: "Your e-bike is legal to ride in Colorado as a Class 1 e-bike.")
        .and have_no_css("[role='alert']")
    end
  end
end
