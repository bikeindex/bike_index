require "rails_helper"

RSpec.describe BikebookController, type: :request do
  describe "show" do
    before { stub_bikebook_catalog }

    it "renders the search and a spinner, and the shell the browser fills in from the catalog" do
      get "/bikebook"

      expect(response).to have_http_status(:ok)
      page = Capybara.string(response.body)
      bikebook = page.find("[data-controller='bikebook--page']")
      expect(bikebook["data-bikebook--page-manifest-url-value"]).to eq Integrations::Bikebook::Catalog::MANIFEST_URL
      expect(bikebook).to have_css("[inert] #vehicle_models[placeholder='Loading…']")
        .and have_css("[role='status'] svg.tw\\:animate-spin")
        .and have_css("[role='status']", text: "Loading the catalog…")
      # its modules all asked for at once, beside the application's rather than repeating them
      preloads = page.all("head link[rel='modulepreload']", visible: :all).map { it[:href] }
      expect(preloads).to include(a_string_matching(%r{/bikebook/catalog-}), a_string_matching(%r{/lit-html-}))
      expect(preloads).to eq preloads.uniq
      # the URL setting nothing, the search as it is until the browser fills it in
      expect(bikebook.find("[inert]")[:class]).to be_blank

      shell = Capybara.string(Nokogiri::HTML5(response.body).at_css("template[data-bikebook--page-target='shell']").inner_html)
      expect(shell).to have_field("vehicle_models", placeholder: "Search by manufacturer or model…")
        .and have_css("#manufacturer-hw-listbox", visible: :all)
        .and have_css("#vehicle-viewers", visible: :all)
      expect(page).to have_title("Bike Book", exact: true)
        .and have_css("meta[property='og:image'][content*='/assets/logos/bikebook']", visible: :all)
        .and have_css("meta[name='twitter:card'][content='summary']", visible: :all)
      expect(response.headers["X-Robots-Tag"]).to be_nil
      expect(page.find("p", text: "Bike Book data is free to use under CC BY-SA 4.0.")).to have_link("Learn how to use it", href: "/bikebook/license")
        .and have_link("view the raw data", href: "https://github.com/bikeindex/bikebook")
        .and have_text("Learn how to use it or view the raw data.", normalize_ws: true)
    end

    context "comparing" do
      it "isn't indexed, and shows the search it can't fill in as loading" do
        get "/bikebook", params: {vehicle_models: "m/segway/2025/gt3-pro,m/aventon/2022/level-2"}
        expect(response).to have_http_status(:ok)
        expect(response.headers["X-Robots-Tag"]).to eq "noindex, follow"
        shell = Capybara.string(response.body).find("[inert]")
        expect(shell[:class]).to be_blank
        expect(shell).to have_field("vehicle_models", placeholder: "Loading…")
      end
    end

    context "cached", :caching do
      include_context :caching_basic

      it "is every visitor's and every search's, the page giving the visitor's market around it" do
        get "/bikebook", params: {search: "1", manufacturer: "aventon"}, headers: {"CF-IPCountry" => "JP"}
        japan = Nokogiri::HTML5(response.body)
        get "/bikebook", params: {search: "1"}, headers: {"CF-IPCountry" => "US"}
        us = Nokogiri::HTML5(response.body)
        # an EU member's visitor in the EU, which the catalog lists their models under
        get "/bikebook", params: {search: "1"}, headers: {"CF-IPCountry" => "FR"}
        france = Nokogiri::HTML5(response.body)

        shell = "template[data-bikebook--page-target='shell']"
        expect(us.at_css(shell).inner_html).to eq japan.at_css(shell).inner_html
        expect(us.at_css(shell).inner_html).to_not include("default-market-value")
        expect(us.at_css(shell).inner_html).to include(%(data-jurisdiction="NY"))
        expect(japan.at_css("[inert]")[:class]).to eq "tw:invisible"
        expect(us.at_css("[inert]")[:class]).to be_blank
        expect([japan, us, france].map { it.at_css("[data-controller='bikebook--page']").attributes.slice(*%w[market market-name jurisdiction].map { "data-bikebook--page-#{it}-value" }).transform_values(&:value).values })
          .to eq [%w[JP Japan US], ["US", "United States", "US"], ["EU", "European Union", "US"]]
        expect(response.body).to include("https://github.com/bikeindex/bikebook (CC BY-SA 4.0). Clone that repository instead.")
        expect(us.at_css("[data-controller='bikebook--page'] > noscript").text).to include("AI agents: get the data there")
          .and include("github.com/bikeindex/bikebook")
      end

      it "isn't kept while the catalog doesn't answer, which leaves the state laws out" do
        WebMock.stub_request(:get, /#{Regexp.escape(Integrations::Bikebook::Catalog::URL)}/o).to_return(status: 503)
        shells = 2.times.map do
          get "/bikebook", params: {search: "1"}
          Nokogiri::HTML5(response.body).at_css("template[data-bikebook--page-target='shell']").inner_html
        end

        expect(shells.first).to_not eq shells.last
        expect(shells.first).to_not include("data-jurisdiction=\"NY\"")
      end
    end

    context "in a frame" do
      it "doesn't autofocus the search, which would take the host page's focus" do
        get "/bikebook"
        expect(Capybara.string(response.body)).to have_css("#vehicle_models[autofocus]")

        get "/bikebook", headers: {"Sec-Fetch-Dest" => "iframe"}
        expect(response).to have_http_status(:ok)
        expect(Capybara.string(response.body)).to have_css("#vehicle_models")
          .and have_no_css("#vehicle_models[autofocus]")
      end
    end

    context "the search the server can't fill in" do
      let(:shell_class) { Capybara.string(response.body).find("[inert]")[:class] }

      it "is blank with filters" do
        get "/bikebook", params: {search: "1", manufacturer: "aventon"}
        expect(shell_class).to eq "tw:invisible"
      end

      it "is blank with filters and picks" do
        get "/bikebook", params: {vehicle_models: "m/segway/2025/gt3-pro,m/aventon/2022/level-2", electric: "1"}
        expect(shell_class).to eq "tw:invisible"
      end

      it "shows when asked for alone" do
        get "/bikebook", params: {search: "1"}
        expect(shell_class).to be_blank
      end
    end

    it "moves an older link's underscored ids to the catalog's dashed ones, leaving what's picked and the search as they are" do
      get "/bikebook", params: {vehicle_models: "m/aventon/2022/level_2{size:M/L}{color:Sage_Green},m/segway/2025/gt3_pro",
                                classifications: "evc/us/class_3,evc/out_of_class/us/ca", electric: "class_2,1", q: "level_2"}
      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to("/bikebook?classifications=evc/us/class-3,evc/out-of-class/us/ca&electric=class-2,1&q=level_2" \
        "&vehicle_models=m/aventon/2022/level-2{size:M/L}{color:Sage_Green},m/segway/2025/gt3-pro")
      # its filters' slugs too, which 2.0.0 renamed some of
      get "/bikebook", params: {manufacturer: "riese_and_muller,trek", vehicle_type: "bike,cargo_bike_rear", primary_activity: "road_endurance,atb_gravel",
                                frame_material: "carbon", handlebar_type: "drop_bar"}
      expect(response).to redirect_to("/bikebook?frame_material=composite&handlebar_type=drop_bar&manufacturer=riese-and-muller,trek" \
        "&primary_activity=road-endurance-sportive,atb-gravel&vehicle_type=bike,cargo-rear")
    end

    context "a model alone" do
      include BikebookCatalogHelpers

      let(:catalog_status) { 200 }
      let(:params) { {vehicle_models: "m/segway/2025/gt3-pro{size:M}{json}", filters: "1"} }
      let(:page) { Capybara.string(response.body) }

      before do
        stub_bikebook_catalog(status: catalog_status)
        get("/bikebook", params:)
      end
      after { WebMock.reset! }

      it "renders the model's page, titled and described for it, canonically without the search or what's picked for it" do
        expect(response).to have_http_status(:ok)
        expect(response.headers["X-Robots-Tag"]).to be_nil
        expect(page).to have_title("Segway GT3 Pro", exact: true)
          .and have_css("[data-controller='bikebook--page'][data-bikebook--page-title-value='Bike Book']")
        expect(page).to have_css("meta[name='description'][content^='Experience elite performance with the Segway GT3 Pro']", visible: :all)
          .and have_css("meta[property='og:image'][content='https://bikebook.bikeindex.org/segway/2025/gt3_pro.png']", visible: :all)
          .and have_css("meta[name='twitter:card'][content='summary_large_image']", visible: :all)
          .and have_css("link[rel='canonical'][href='http://www.example.com/bikebook?vehicle_models=m/segway/2025/gt3-pro']", visible: :all)
        # its search hidden from the start, as the browser hides it
        expect(page.find("[inert]", visible: :all)[:class]).to eq "tw:hidden"
      end

      context "that the catalog hasn't" do
        let(:params) { {vehicle_models: "m/segway-ninebot/2025/gt-9"} }

        it "is not found" do
          expect(response).to have_http_status(:not_found)
        end
      end

      context "with the catalog unreachable" do
        let(:catalog_status) { 503 }

        it "renders the page for the browser to try, as unavailable to a crawler" do
          expect(response).to have_http_status(:service_unavailable)
          expect(page).to have_title("Bike Book", exact: true)
            .and have_css("link[rel='canonical'][href='http://www.example.com/bikebook?vehicle_models=m/segway/2025/gt3-pro']", visible: :all)
        end
      end
    end

    describe "donation strip" do
      let(:page) do
        get "/bikebook"
        Capybara.string(response.body)
      end

      it "renders under the Bike Book heading" do
        expect(page).to have_css("h1", text: "find your next ride.")
        expect(page.find("section[aria-label='Donate to Bike Index']")).to have_link("Donate", href: "/donate?source=bikebook")
          .and have_no_css("button")
      end
    end

    describe "units" do
      let(:headers) { {} }
      let(:html_class) do
        get("/bikebook", headers:)
        Nokogiri::HTML5(response.body).at_css("html")["class"]
      end

      it "is metric" do
        expect(html_class).to be_blank
      end

      context "from the US" do
        let(:headers) { {"HTTP_CF_IPCOUNTRY" => "US"} }

        it "is imperial" do
          expect(html_class).to eq "imperial"
        end

        context "with a user who prefers metric" do
          include_context :request_spec_logged_in_as_user
          before { current_user.update(preferred_unit_system: "metric") }

          it "is metric" do
            expect(html_class).to be_blank
          end
        end
      end
    end
  end

  describe "vehicle" do
    it "redirects to the page with that vehicle picked" do
      get "/bikebook/m/segway/2025/gt3-pro"
      expect(response).to redirect_to("/bikebook?vehicle_models=m/segway/2025/gt3-pro")
    end

    it "redirects from the vehicle's id alone, an older link's for show to dash" do
      get "/m/velotric/2024/fold_1"
      expect(response).to redirect_to("/bikebook?vehicle_models=m/velotric/2024/fold_1")
      get "/m/super-73/2024/s-adv"
      expect(response).to redirect_to("/bikebook?vehicle_models=m/super-73/2024/s-adv")
    end

    it "redirects from an e-vehicle classification's id to its card" do
      get "/evc/us/class-3"
      expect(response).to redirect_to("/bikebook?classifications=evc/us/class-3")
      get "/evc/off_highway_motorcycle"
      expect(response).to redirect_to("/bikebook?classifications=evc/off_highway_motorcycle")
    end

    context "without its m/, and with vehicles already picked" do
      it "picks it ahead of them, keeping the query" do
        get "/bikebook/segway/2025/gt3_pro", params: {vehicle_models: "m/aventon/2022/level_2,m/segway/2025/gt3_pro", filters: "1"}
        expect(response).to redirect_to("/bikebook?filters=1&vehicle_models=m/segway/2025/gt3_pro,m/aventon/2022/level_2")
      end

      context "with what's picked for each" do
        it "keeps each with its vehicle, a name's commas its own" do
          vehicle_models = "m/aventon/2022/level-2{size:Large}{json},m/segway/2025/gt3-pro{color:Navy, Fade},m/aventon/2026/current-adv{size:Small}{color:Sage}"
          get "/bikebook/m/segway/2025/gt3-pro", params: {vehicle_models:}
          expect(response).to redirect_to("/bikebook?vehicle_models=m/segway/2025/gt3-pro{color:Navy,+Fade},m/aventon/2022/level-2{size:Large}{json},m/aventon/2026/current-adv{size:Small}{color:Sage}")
        end
      end
    end
  end

  describe "other spellings" do
    it "redirects them to /bikebook, keeping the rest of the path and the query" do
      get "/BikeBook"
      expect(response).to redirect_to("/bikebook")
      expect(response).to have_http_status(:moved_permanently)

      get "/bike-book?vehicle_models=m/segway/2025/gt3-pro"
      expect(response).to redirect_to("/bikebook?vehicle_models=m/segway/2025/gt3-pro")

      get "/bike_book/m/segway/2025/gt3-pro"
      expect(response).to redirect_to("/bikebook/m/segway/2025/gt3-pro")
    end
  end

  describe "up", vcr: {cassette_name: "bikebook-up"} do
    # WebMock stubs outlive their examples here, and answer ahead of the cassette
    before do
      WebMock.reset!
      Rails.cache.clear
    end

    it "is ok, in the format the browser's reader reads" do
      get "/up/bikebook"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(<body style="background-color: green">))
      %w[catalog_worker similarity].each do |reader|
        expect(Rails.root.join("app/javascript/bikebook/#{reader}.js").read).to include("const FORMAT = #{Integrations::Bikebook::Catalog::FORMAT}\n")
      end
    end

    context "with the catalog in a format the reader doesn't read" do
      it "is unavailable" do
        stub_const("Integrations::Bikebook::Catalog::FORMAT", 2)
        get "/up/bikebook"
        expect(response).to have_http_status(:service_unavailable)
        expect(response.body).to include(%(<body style="background-color: red">))
      end
    end

    context "with no catalog published", vcr: {cassette_name: "bikebook-up_not_found"} do
      it "is unavailable" do
        stub_const("Integrations::Bikebook::Catalog::URL", "https://bikebook-catalog.bikeindex.org/not_a_catalog/")
        get "/up/bikebook"
        expect(response).to have_http_status(:service_unavailable)
        expect(response.body).to include(%(<body style="background-color: red">))
      end
    end
  end

  describe "license" do
    let(:section_ids) do
      %w[what-you-can-do what-you-need-to-do how-to-credit share-alike what-this-license-covers disclaimer
        contributing versions-and-downloads show-that-you-use-bike-book questions]
    end

    it "renders the license, with an anchor for each section and its credit snippets" do
      get "/bikebook/license"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<title>Bike Book license and attribution | Bike Index</title>")
      page = Capybara.string(response.body)
      expect(page).to have_css("h1", text: "Bike Book license and attribution")
      section_ids.each { expect(page).to have_css("h2##{it}") }
      expect(page.find("meta[name='description']", visible: false)["content"])
        .to eq "Bike Book data is open under CC BY-SA 4.0. Here's how to use it and how to credit Bike Index."
      expect(page.find("link[rel='canonical']", visible: false)["href"]).to eq "https://bikeindex.org/bikebook/license"
      # the pointers to sections link to them
      expect(page).to have_link("How to credit Bike Book", href: "#how-to-credit")
        .and have_link("Share-alike: what has to stay open", href: "#share-alike")
      # no copy waits on a person to fill it in; the Markdown snippet's own brackets are in a pre
      expect(page.all("h2, p, li, td").map(&:text).join).not_to match(/\[[^\]]+\]/)
      # every address is a mailto link
      expect(page.all("a[href='mailto:licensing@bikeindex.org']").count).to eq 6
      expect(page.find("body").text.scan("licensing@bikeindex.org").count).to eq 6
      expect(page).to have_css("li", text: "Product descriptions and photos, which belong to their manufacturers", normalize_ws: true)
      # snippets are text, with a button to copy each
      expect(page).to have_css("pre code", text: 'Bike data: <a href="https://bikeindex.org/bikebook/license">Bike Book by Bike Index</a>')
        .and have_css("pre code", text: "Bike data: [Bike Book by Bike Index](https://bikeindex.org/bikebook/license)")
      expect(page).to have_css("[data-controller='ui--copy-button']", count: 2)
      expect(page).to have_css("table th", text: "Where you use the data")
      expect(page).to have_css("#badge img[alt='Powered by Bike Index']", count: 4)
      expect(page).to have_link("SVG", count: 4).and have_link("PNG 2x", count: 4).and have_link("PNG 4x", count: 4)
      page.all("a[download]").each do |link|
        expect(Rails.public_path.join(link["href"].delete_prefix("/"))).to exist
      end
    end
  end

  describe "schema_viewer" do
    before { stub_bikebook_catalog }

    let(:fields) { Integrations::Bikebook::Catalog.schema_viewer.dig("documents", "vehicle_model", "fields") }
    let(:manufacturer_count) { fields.dig("manufacturer", "models_count") }
    let(:example_id) { fields.dig("manufacturer", "example_ids").first }

    it "renders the vehicle model's fields with how many models fill each, opening what the URL names and the folds around it" do
      get "/bikebook_schema", params: {open: "type,frame.mounts", by_count: "type"}

      expect(response).to have_http_status(:ok)
      page = Capybara.string(response.body)
      expect(page).to have_title("Bike Book schemas | Bike Index", exact: true)
        .and have_css("[aria-current='page']", text: "Vehicle model")
        .and have_css("details[open][data-schema-path='type']")
        .and have_css("details:not([open])[data-schema-path='type_detail']")
        # opened around the fold it names, and closed everywhere else
        .and have_css("details[open][data-schema-path='frame'] details[open][data-schema-path='frame.mounts']")
        .and have_css("details:not([open])[data-schema-path='wheels']")
        .and have_css("input[aria-label='type by count'][checked]")
        .and have_css("button[aria-label='#{ActiveSupport::NumberHelper.number_to_delimited(manufacturer_count)} models']")
        .and have_link(example_id, href: "/bikebook?vehicle_models=#{example_id}", visible: :all)
    end

    context "with another document" do
      it "renders its fields" do
        get "/bikebook_schema", params: {document: "e_vehicle_classification"}

        expect(response).to have_http_status(:ok)
        expect(Capybara.string(response.body)).to have_css("[aria-current='page']", text: "E vehicle classification")
          .and have_content("jurisdiction:")
      end
    end

    context "with caching" do
      around do |example|
        ActionController::Base.perform_caching = true
        ActionController::Base.cache_store = ActiveSupport::Cache::MemoryStore.new
        example.run
      ensure
        ActionController::Base.perform_caching = false
        ActionController::Base.cache_store = :null_store
      end

      context "when the catalog publishes a new schema viewer" do
        let(:url) { Integrations::Bikebook::Catalog::URL }
        let(:viewer) { JSON.parse(BikebookCatalogHelpers::FIXTURES.join("schema_viewer.json").read) }
        let(:republished) { viewer.deep_merge("documents" => {"vehicle_model" => {"fields" => {"manufacturer" => {"models_count" => 12_345_678}}}}) }
        let(:manifest) { JSON.parse(BikebookCatalogHelpers::FIXTURES.join(Integrations::Bikebook::Catalog::MANIFEST).read) }

        it "renders the new file's counts rather than the cached ones" do
          # model and first_year fill as many models as manufacturer does
          old_badge = "button[aria-label='#{ActiveSupport::NumberHelper.number_to_delimited(manufacturer_count)} models']"
          get "/bikebook_schema"
          old_badges = Capybara.string(response.body).all(old_badge).count

          WebMock.stub_request(:get, "#{url}schema_viewer.v2.json").to_return(body: republished.to_json)
          WebMock.stub_request(:get, "#{url}#{Integrations::Bikebook::Catalog::MANIFEST}")
            .to_return(body: manifest.merge("schema_viewer" => "schema_viewer.v2.json").to_json)
          # the manifest keeps 5 minutes
          Rails.cache.clear
          get "/bikebook_schema"

          expect(Capybara.string(response.body)).to have_css("button[aria-label='12,345,678 models']")
            .and have_css(old_badge, count: old_badges - 1)
        end
      end

      it "caches a field's fields inside its fragment, and on their own only where it renders afresh" do
        written = []
        record = ->(*, payload) { written << payload[:key].to_s }
        ActiveSupport::Notifications.subscribed(record, "cache_write.active_support") { get "/bikebook_schema" }
        expect(written.count { it.include?("/frame/") }).to eq 1
        expect(written.count { it.include?("/frame.mounts/") }).to eq 0

        written.clear
        ActiveSupport::Notifications.subscribed(record, "cache_write.active_support") { get "/bikebook_schema", params: {open: "frame"} }
        expect(written.count { it.include?("/frame.mounts/") }).to eq 1
      end

      it "renders a field the URL opens anything in afresh, rather than as cached closed" do
        get "/bikebook_schema"
        expect(Capybara.string(response.body)).to have_css("details:not([open])[data-schema-path='type']")

        get "/bikebook_schema", params: {open: "type", by_count: "type"}

        page = Capybara.string(response.body)
        expect(page).to have_css("details[open][data-schema-path='type']")
          .and have_css("input[aria-label='type by count'][checked]")
          .and have_css("details:not([open])[data-schema-path='type_detail']")
          .and have_css("button[aria-label='#{ActiveSupport::NumberHelper.number_to_delimited(manufacturer_count)} models']")
      end
    end

    context "while the catalog doesn't answer" do
      before { WebMock.stub_request(:get, "#{Integrations::Bikebook::Catalog::URL}#{Integrations::Bikebook::Catalog::MANIFEST}").to_return(status: 503) }

      it "says so" do
        get "/bikebook_schema", params: {document: "component"}

        expect(response).to have_http_status(:service_unavailable)
        expect(Capybara.string(response.body)).to have_content("Bike Book's catalog isn't answering")
          .and have_no_css("[aria-current='page']")
      end
    end

    context "with a document the catalog doesn't publish" do
      it "renders the vehicle model's" do
        get "/bikebook_schema", params: {document: "vocabulary"}

        expect(Capybara.string(response.body)).to have_css("[aria-current='page']", text: "Vehicle model")
      end
    end
  end
end
