require "rails_helper"

RSpec.describe BikebookController, type: :request do
  describe "show" do
    it "renders the shell the browser fills in from the catalog" do
      get "/bikebook"

      expect(response).to have_http_status(:ok)
      page = Capybara.string(response.body)
      bikebook = page.find("[data-controller='bikebook--page']")
      expect(bikebook["data-bikebook--page-manifest-url-value"]).to eq BikebookController::MANIFEST_URL
      expect(bikebook).to have_text("Loading the catalog…")

      shell = Capybara.string(Nokogiri::HTML5(response.body).at_css("template[data-bikebook--page-target='shell']").inner_html)
      expect(shell).to have_field("vehicle_models", placeholder: "Search by manufacturer or model…")
        .and have_css("#manufacturer-hw-listbox", visible: :all)
        .and have_css("#vehicle-viewers", visible: :all)
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
end
