require "rails_helper"

RSpec.describe BikebookController, type: :request do
  describe "show" do
    it "renders the search and a spinner, and the shell the browser fills in from the catalog" do
      get "/bikebook"

      expect(response).to have_http_status(:ok)
      page = Capybara.string(response.body)
      bikebook = page.find("[data-controller='bikebook--page']")
      expect(bikebook["data-bikebook--page-manifest-url-value"]).to eq Integrations::BikebookCatalog::MANIFEST_URL
      expect(bikebook).to have_css("[inert] #vehicle_models")
        .and have_css("[role='status'] svg.tw\\:animate-spin")

      shell = Capybara.string(Nokogiri::HTML5(response.body).at_css("template[data-bikebook--page-target='shell']").inner_html)
      expect(shell).to have_field("vehicle_models", placeholder: "Search by manufacturer or model…")
        .and have_css("#manufacturer-hw-listbox", visible: :all)
        .and have_css("#vehicle-viewers", visible: :all)
      expect(page).to have_title("Bikebook", exact: true)
      expect(response.headers["X-Robots-Tag"]).to be_nil
    end

    context "comparing" do
      it "isn't indexed" do
        get "/bikebook", params: {vehicle_models: "m/segway/2025/gt3_pro,m/aventon/2022/level_2"}
        expect(response).to have_http_status(:ok)
        expect(response.headers["X-Robots-Tag"]).to eq "noindex, follow"
      end
    end

    context "a model alone" do
      it "redirects to its page, keeping the query" do
        get "/bikebook", params: {vehicle_models: "m/segway/2025/gt3_pro", filters: "1"}
        expect(response).to have_http_status(:moved_permanently)
        expect(response).to redirect_to("/bikebook/m/segway/2025/gt3_pro?filters=1")
      end

      context "an e-vehicle classification" do
        it "renders, unindexed" do
          get "/bikebook", params: {vehicle_models: "evc/us/class_3"}
          expect(response).to have_http_status(:ok)
          expect(response.headers["X-Robots-Tag"]).to eq "noindex, follow"
        end
      end
    end

    describe "donation strip" do
      let(:page) do
        get "/bikebook"
        Capybara.string(response.body)
      end

      it "renders under the Bike Book heading" do
        expect(page).to have_css("h1", text: "across 70,000+ models")
        expect(page.find("section[aria-label='Donate to Bike Index']")).to have_link("Donate", href: "/donate?source=bikebook")
          .and have_css("button[aria-label='Dismiss']")
      end

      context "dismissed" do
        before { cookies["bikebook_donate_dismissed"] = "1" }

        it "renders the heading alone" do
          expect(page).to have_css("h1", text: "across 70,000+ models")
          expect(page).to have_no_css("section[aria-label='Donate to Bike Index']")
        end
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
    let(:fixtures) { Rails.root.join("spec/fixtures/bikebook_catalog") }
    let(:catalog_status) { 200 }
    let(:page) { Capybara.string(response.body) }

    before do
      Rails.cache.clear
      WebMock.stub_request(:get, /\A#{Regexp.escape(Integrations::BikebookCatalog::URL)}/o).to_return { |request|
        {status: catalog_status, body: (fixtures.join(request.uri.path.delete_prefix("/catalog/")).read if catalog_status == 200)}
      }
    end
    after { WebMock.reset! }

    it "renders the model's page, titled and described for it" do
      get "/bikebook/m/segway/2025/gt3_pro"
      expect(response).to have_http_status(:ok)
      expect(response.headers["X-Robots-Tag"]).to be_nil
      expect(page).to have_title("Segway GT3 Pro", exact: true)
        .and have_css("[data-controller='bikebook--page'][data-bikebook--page-title-value='Bikebook']")
      expect(page).to have_css("meta[name='description'][content^='Experience elite performance with the Segway GT3 Pro']", visible: :all)
        .and have_css("meta[property='og:image'][content='https://bikebook.bikeindex.org/segway/2025/gt3_pro.png']", visible: :all)
        .and have_css("link[rel='canonical'][href$='/bikebook/m/segway/2025/gt3_pro']", visible: :all)
    end

    context "without its m/" do
      it "redirects to its page" do
        get "/bikebook/segway/2025/gt3_pro", params: {filters: "1"}
        expect(response).to have_http_status(:moved_permanently)
        expect(response).to redirect_to("/bikebook/m/segway/2025/gt3_pro?filters=1")
      end
    end

    context "a model the catalog hasn't" do
      it "is not found" do
        get "/bikebook/m/segway/2025/gt9"
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with the catalog unreachable" do
      let(:catalog_status) { 503 }

      it "renders the page, for the browser to try" do
        get "/bikebook/m/segway/2025/gt3_pro"
        expect(response).to have_http_status(:ok)
        expect(page).to have_title("Bikebook", exact: true)
      end
    end

    context "an e-vehicle classification" do
      it "picks it, without an m/" do
        get "/bikebook/evc/us/class_3"
        expect(response).to redirect_to("/bikebook?vehicle_models=evc/us/class_3")
      end
    end

    context "without its m/, and with vehicles already picked" do
      it "picks it ahead of them, keeping the query" do
        get "/bikebook/segway/2025/gt3_pro", params: {vehicle_models: "m/aventon/2022/level_2,m/segway/2025/gt3_pro", filters: "1"}
        expect(response).to redirect_to("/bikebook?filters=1&vehicle_models=m/segway/2025/gt3_pro,m/aventon/2022/level_2")
      end

      context "with sizes picked" do
        it "moves each size with its vehicle" do
          get "/bikebook/m/segway/2025/gt3_pro", params: {vehicle_models: "m/aventon/2022/level_2,m/segway/2025/gt3_pro,m/aventon/2026/current_adv", vehicle_sizes: "Large,,Small"}
          expect(response).to redirect_to("/bikebook?vehicle_models=m/segway/2025/gt3_pro,m/aventon/2022/level_2,m/aventon/2026/current_adv&vehicle_sizes=,Large,Small")
        end
      end
    end
  end
end
