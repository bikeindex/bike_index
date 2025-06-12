require "rails_helper"

RSpec.describe MarketplaceController, type: :request do
  let(:base_url) { "/marketplace" }

  describe "index" do
    let!(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale) }
    let!(:marketplace_listing_draft) { FactoryBot.create(:marketplace_listing, status: :draft) }
    let(:bike_id) { marketplace_listing.item_id }

    it "renders" do
      get base_url
      expect(flash).to be_blank
      expect(response).to render_template("index")
      expect(assigns(:interpreted_params)).to eq(stolenness: "all")
      expect(assigns(:bikes)).to be_blank
    end

    context "with search_no_js" do
      it "renders with bikes" do
        expect(MarketplaceListing.pluck(:status)).to match_array(%w[for_sale draft])
        expect(Bike.for_sale.pluck(:id)).to eq([bike_id])
        get "#{base_url}?search_no_js=true"
        expect(response.code).to eq("200")
        expect(response).to render_template(:index)
        expect(assigns(:interpreted_params)).to eq(stolenness: "all")
        expect(assigns(:bikes).pluck(:id)).to eq([bike_id])
      end
    end

    context "turbo_stream" do
      it "renders" do
        get base_url, as: :turbo_stream
        expect(response.media_type).to eq Mime[:turbo_stream].to_s
        expect(response.content_type).to include("text/vnd.turbo-stream.html")
        expect(response).to have_http_status(:success)

        expect(response.body).to include("<turbo-stream action=\"replace\" target=\"search_marketplace_results_frame\">")
        expect(response).to render_template(:index)
        expect(assigns(:interpreted_params)).to eq(stolenness: "all")
        expect(assigns(:bikes).pluck(:id)).to eq([bike_id])
        # Expect there to be a link to the bike url
        expect(response.body).to match(/href="#{ENV["BASE_URL"]}\/bikes\/#{bike_id}"/)
      end
    end
  end
end
