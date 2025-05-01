require "rails_helper"

RSpec.describe MarketplaceListingsController, type: :request do
  include_context :request_spec_logged_in_as_user_if_present
  let(:base_url) { "/marketplace_listings" }
  let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, primary_activity: FactoryBot.create(:primary_activity), cycle_type: "e-scooter") }
  let(:current_user) { bike.user }
  let(:address_record) { FactoryBot.create(:address_record, user: current_user, kind: :user) }
  let!(:marketplace_listing) { FactoryBot.create(:marketplace_listing, item: bike, address_record:) }

  describe "publish" do
    it "publishes" do
      expect(marketplace_listing.reload.status).to eq "draft"
      expect(marketplace_listing.valid_publishable?).to be_truthy
      expect(marketplace_listing.errors.full_messages).to be_blank

      patch "#{base_url}/#{marketplace_listing.to_param}", params: {marketplace_listing: {status: :for_sale}}
      expect(flash[:success]).to eq "Your e-Scooter has been published. It is now listed for sale!"
      expect(response).to redirect_to(root_url)
      expect(marketplace_listing.reload.status).to eq "for_sale"
      expect(marketplace_listing.published_at).to be_within(1).of Time.current
      expect(bike.reload.is_for_sale).to be_truthy
    end

    context "not authorized" do
      let(:current_user) { FactoryBot.create(:user) }

      it "responds with flash error and doesn't publish" do
        expect(marketplace_listing.reload.status).to eq "draft"
        expect(marketplace_listing.valid_publishable?).to be_truthy
        expect(marketplace_listing.errors.full_messages).to be_blank

        patch "#{base_url}/#{marketplace_listing.to_param}", params: {marketplace_listing: {status: :for_sale}}
        expect(flash[:error]).to eq "Oh no! It looks like you don't own that e-Scooter."
        expect(response).to redirect_to(root_url)
        expect(marketplace_listing.reload.status).to eq "draft"
      end
    end

    context "not valid_publishable" do
      let(:address_record) { nil }

      it "responds with flash error and doesn't publish" do
        expect(marketplace_listing.reload.status).to eq "draft"
        expect(marketplace_listing.valid_publishable?).to be_falsey

        patch "#{base_url}/#{marketplace_listing.to_param}", params: {marketplace_listing: {status: :for_sale}}
        expect(flash[:error]).to eq "Location is required - please set at least a city"
        expect(response).to redirect_to(root_url)
        expect(marketplace_listing.reload.status).to eq "draft"
      end
    end
  end
end
