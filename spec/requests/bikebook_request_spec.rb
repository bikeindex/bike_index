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
      expect(bikebook).to have_css("[inert] #vehicle_models")
        .and have_css("[role='status'] svg.tw\\:animate-spin")
      # the URL setting nothing, the search as it is until the browser fills it in
      expect(bikebook.find("[inert]")[:class]).to be_blank

      shell = Capybara.string(Nokogiri::HTML5(response.body).at_css("template[data-bikebook--page-target='shell']").inner_html)
      expect(shell).to have_field("vehicle_models", placeholder: "Search by manufacturer or model…")
        .and have_css("#manufacturer-hw-listbox", visible: :all)
        .and have_css("#vehicle-viewers", visible: :all)
      expect(page).to have_title("Bike Book", exact: true)
        .and have_css("meta[property='og:image'][content*='/assets/logos/bikebook_icon']", visible: :all)
        .and have_css("meta[name='twitter:card'][content='summary']", visible: :all)
      expect(response.headers["X-Robots-Tag"]).to be_nil
    end

    context "comparing" do
      it "isn't indexed, and shows the search it can't fill in as loading" do
        get "/bikebook", params: {vehicle_models: "m/segway/2025/gt3_pro,m/aventon/2022/level_2"}
        expect(response).to have_http_status(:ok)
        expect(response.headers["X-Robots-Tag"]).to eq "noindex, follow"
        shell = Capybara.string(response.body).find("[inert]")
        expect(shell[:class]).to be_blank
        expect(shell).to have_field("vehicle_models", placeholder: "Loading…")
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
        get "/bikebook", params: {vehicle_models: "m/segway/2025/gt3_pro,m/aventon/2022/level_2", electric: "1"}
        expect(shell_class).to eq "tw:invisible"
      end

      it "shows when asked for alone" do
        get "/bikebook", params: {search: "1"}
        expect(shell_class).to be_blank
      end
    end

    context "a model alone" do
      include BikebookCatalogHelpers

      let(:catalog_status) { 200 }
      let(:params) { {vehicle_models: "m/segway/2025/gt3_pro{size:M}{json}", filters: "1"} }
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
          .and have_css("link[rel='canonical'][href='http://www.example.com/bikebook?vehicle_models=m/segway/2025/gt3_pro']", visible: :all)
        # its search hidden from the start, as the browser hides it
        expect(page.find("[inert]", visible: :all)[:class]).to eq "tw:hidden"
      end

      context "that the catalog hasn't" do
        let(:params) { {vehicle_models: "m/segway/2025/gt9"} }

        it "is not found" do
          expect(response).to have_http_status(:not_found)
        end
      end

      context "with the catalog unreachable" do
        let(:catalog_status) { 503 }

        it "renders the page for the browser to try, as unavailable to a crawler" do
          expect(response).to have_http_status(:service_unavailable)
          expect(page).to have_title("Bike Book", exact: true)
            .and have_css("link[rel='canonical'][href='http://www.example.com/bikebook?vehicle_models=m/segway/2025/gt3_pro']", visible: :all)
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
      get "/bikebook/m/segway/2025/gt3_pro"
      expect(response).to redirect_to("/bikebook?vehicle_models=m/segway/2025/gt3_pro")
    end

    it "redirects from the vehicle's id alone" do
      get "/m/velotric/2024/fold_1"
      expect(response).to redirect_to("/bikebook?vehicle_models=m/velotric/2024/fold_1")
    end

    it "redirects from an e-vehicle classification's id to its card" do
      get "/evc/us/class_3"
      expect(response).to redirect_to("/bikebook?classifications=evc/us/class_3")
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
          vehicle_models = "m/aventon/2022/level_2{size:Large}{json},m/segway/2025/gt3_pro{color:Navy, Fade},m/aventon/2026/current_adv{size:Small}{color:Sage}"
          get "/bikebook/m/segway/2025/gt3_pro", params: {vehicle_models:}
          expect(response).to redirect_to("/bikebook?vehicle_models=m/segway/2025/gt3_pro{color:Navy,+Fade},m/aventon/2022/level_2{size:Large}{json},m/aventon/2026/current_adv{size:Small}{color:Sage}")
        end
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
      expect(page.all("a[href='mailto:licensing@bikeindex.org']").count).to eq 5
      expect(page.find("body").text.scan("licensing@bikeindex.org").count).to eq 5
      # snippets are text, with a button to copy each
      expect(page).to have_css("pre code", text: 'Bike data: <a href="https://bikeindex.org/bikebook/license">Bike Book by Bike Index</a>')
        .and have_css("pre code", text: "Bike data: [Bike Book by Bike Index](https://bikeindex.org/bikebook/license)")
      expect(page).to have_css("[data-controller='ui--copy-button']", count: 2)
      expect(page).to have_css("table th", text: "Where you use the data")
      # the badges, with a download of each file
      expect(page).to have_css("#badge img[alt='Powered by Bike Index']", count: 4)
      expect(page).to have_link("SVG", count: 4).and have_link("PNG 2x", count: 4).and have_link("PNG 4x", count: 4)
      page.all("a[download]").each do |link|
        expect(Rails.public_path.join(link["href"].delete_prefix("/"))).to exist
      end
    end
  end
end
