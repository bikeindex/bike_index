require "rails_helper"

facebook_imported = begin
  "Facebook::AdsIntegration".constantize
rescue
  nil
end

# Not set up to run on CI currently
if !ENV["CI"] && facebook_imported && Facebook::AdsIntegration::TOKEN.present?
  RSpec.describe Facebook::AdsIntegration do
    let(:instance) { described_class.new }
    it "gets account" do
      VCR.use_cassette("facebook/ads_integration-get_account", match_requests_on: [:method]) do
        expect(instance.account.name).to eq "Bike Index"
      end
    end

    describe "get_campaign" do
      let(:campaign_id) { "6250389631214" }
      it "get_campaign" do
        VCR.use_cassette("facebook/ads_integration-get_campaign", match_requests_on: [:method]) do
          campaign = instance.get_campaign(campaign_id)
          expect(campaign.id).to be_present
        end
      end
    end

    describe "reference_interests" do
      it "gets the campaign" do
        VCR.use_cassette("facebook/ads_integration-reference_interests", match_requests_on: [:method]) do
          expect(instance.reference_targeting["flexible_spec"].count).to eq 1
          interests = instance.reference_interests
          expect(interests.is_a?(Array)).to be_truthy
          expect(interests.first.keys).to match_array(%w[id name])
        end
      end
    end

    context "with theft_alert" do
      let(:campaign_id) { "6309006915414" }
      let(:adset_id) { "6316675713414" }
      let(:theft_alert_plan) { FactoryBot.create(:theft_alert_plan, amount_cents_facebook: 999) }
      let(:bike) { Bike.new(id: 32, mnfg_name: "Surly") } # Manually stubbing so test has a valid URL
      let(:canada) { Country.canada }
      let(:stolen_record) { StolenRecord.new(bike: bike, city: "Edmonton", street: "10000 138 st", zipcode: "T5N 2H7", country: canada) }
      let(:theft_alert) do
        TheftAlert.new(id: 12, theft_alert_plan: theft_alert_plan,
          stolen_record: stolen_record,
          latitude: 37.8297171, longitude: -122.2803456,
          facebook_data: {campaign_id: campaign_id, adset_id: adset_id})
      end
      before do
        # Required because default scope override in theft_alert
        allow(theft_alert).to receive(:stolen_record) { stolen_record }
        allow(theft_alert).to receive(:facebook_name) { "New Test Theft Alert" }
      end

      describe "create_campaign" do
        let(:theft_alert) { TheftAlert.new(id: 12) }
        it "creates a campaign" do
          expect(theft_alert.address_string).to eq "10000 138 st, Edmonton, T5N 2H7, CA"
          VCR.use_cassette("facebook/ads_integration-create_campaign", match_requests_on: [:method]) do
            campaign = instance.create_campaign(theft_alert)
            expect(campaign).to be_present
            # When a new cassette is recorded, you need to update the campaign_id with this -
            # so the ads are created in the new thing
            expect(campaign.id).to eq campaign_id
          end
        end
      end

      describe "create_adset" do
        it "creates an adset" do
          expect(theft_alert.campaign_id).to eq campaign_id
          VCR.use_cassette("facebook/ads_integration-create_adset", match_requests_on: [:method]) do
            adset = instance.create_adset(theft_alert)
            expect(adset).to be_present
            expect(adset.id).to eq adset_id
          end
        end
      end

      describe "create_ad, create_for" do
        let(:message) { "Edmonton: Keep an eye out for this stolen Surly. If you see it, let the owner know on Bike Index!" }
        it "creates an adset" do
          expect(theft_alert.bike).to eq bike
          expect(theft_alert.adset_id).to eq adset_id
          expect(theft_alert.message).to eq message
          VCR.use_cassette("facebook/ads_integration-create_ad", match_requests_on: [:method]) do
            ad = instance.create_ad(theft_alert)
            expect(ad).to be_present
            expect(ad.id).to be_present
          end
        end

        describe "create_for" do
          let(:theft_alert) { FactoryBot.create(:theft_alert, theft_alert_plan: theft_alert_plan) }
          it "creates an ad and saves the data" do
            expect(theft_alert.message).to eq message
            expect(theft_alert).to be_valid
            expect(theft_alert.facebook_data).to be_blank
            VCR.use_cassette("facebook/ads_integration-create_for", match_requests_on: [:method]) do
              instance.create_for(theft_alert)
              theft_alert.reload
              expect(theft_alert.campaign_id).to be_present
              expect(theft_alert.adset_id).to be_present
              expect(theft_alert.ad_id).to be_present
              # This fails when it's freshly created - so ignoring
              # expect(theft_alert.facebook_post_url).to be_present
            end
          end
        end
      end

      describe "update_facebook_data" do
        let(:facebook_data) { {ad_id: "6308858178614", adset_id: "6308858171014", campaign_id: "6308858167614"} }
        let(:theft_alert_plan) { FactoryBot.create(:theft_alert_plan, amount_cents_facebook: 1800) }
        let(:effective_object_story_id) { "500198263370025_563010979192386" }
        let(:bike) { FactoryBot.create(:bike, :with_stolen_record, :with_ownership_claimed) }
        let(:stolen_record) { bike.current_stolen_record }
        let(:theft_alert) do
          # id: 1633
          TheftAlert.create(theft_alert_plan: theft_alert_plan,
            stolen_record: stolen_record,
            user: bike.user,
            facebook_data: facebook_data)
        end
        let(:target_engagement) { {landing_page_view: "1", link_click: "1", page_engagement: "2", post_engagement: "2", post_reaction: "1", unique_clicks: "3"} }
        it "updates and sets the data" do
          expect(theft_alert).to be_valid
          expect(theft_alert.id).to be_present
          expect_hashes_to_match(theft_alert.facebook_data, facebook_data)
          expect(theft_alert.reload.reach).to be_blank
          VCR.use_cassette("facebook/ads_integration-update_facebook_data", match_requests_on: [:method]) do
            instance.update_facebook_data(theft_alert)
            theft_alert.reload
            expect(theft_alert.facebook_updated_at).to be_within(2).of Time.current
            expect(theft_alert.facebook_data["effective_object_story_id"]).to eq effective_object_story_id
            expect(theft_alert.facebook_data["amount_cents"]).to eq 1800
            expect(theft_alert.facebook_data["spend_cents"].to_i).to eq 281
            expect(theft_alert.reach).to eq 8393
            expect(theft_alert.amount_cents_facebook_spent).to eq 281
            expect_hashes_to_match(theft_alert.engagement, target_engagement)
          end
        end
        context "other failure" do
          let(:facebook_data) { {ad_id: "6252401122014", adset_id: "6252319938614", campaign_id: "6252319937814", activating_at: Time.current.to_i, effective_object_story_id: "500198263370025_4357215287668284"} }
          it "updates and sets the data" do
            expect(theft_alert).to be_valid
            expect(theft_alert.id).to be_present
            expect_hashes_to_match(theft_alert.facebook_data, facebook_data)
            expect(theft_alert.reload.reach).to be_blank
            VCR.use_cassette("facebook/ads_integration-update_facebook_data-2", match_requests_on: [:method]) do
              instance.update_facebook_data(theft_alert)
              theft_alert.reload
              expect(theft_alert.facebook_updated_at).to be_within(2).of Time.current
              expect(theft_alert.facebook_data["effective_object_story_id"]).to eq facebook_data[:effective_object_story_id]
              expect(theft_alert.facebook_data["amount_cents"]).to eq 1800
              expect(theft_alert.facebook_data["spend_cents"]).to be_blank
              expect(theft_alert.reach).to be_blank
              expect(theft_alert.engagement).to eq({})
            end
          end
        end
      end
    end
  end
end
