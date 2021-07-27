require "rails_helper"

# Not set up to run on CI currently
if !ENV["CI"] && Facebook::AdsIntegration::TOKEN.present?
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
          interests = instance.reference_interests
          expect(interests.is_a?(Array)).to be_truthy
          expect(interests.first.keys).to match_array(%w[id name])

          custom_audiences = instance.reference_custom_audiences
          expect(custom_audiences.is_a?(Array)).to be_truthy
          expect(custom_audiences.first.keys).to match_array(%w[id name])
        end
      end
    end

    context "with theft_alert" do
      let(:campaign_id) { "6250590176414" }
      let(:adset_id) { "6250590722014" }
      let(:theft_alert_plan) { FactoryBot.create(:theft_alert_plan, amount_cents_facebook: 999) }
      let(:bike) { Bike.new(id: 32, mnfg_name: "Surly") } # Manually stubbing so test has a valid URL
      let(:stolen_record) { StolenRecord.new(bike: bike, city: "Oakland") }
      let(:theft_alert) do
        TheftAlert.new(id: 12, theft_alert_plan: theft_alert_plan,
                       stolen_record: stolen_record,
                       latitude: 37.8297171, longitude: -122.2803456,
                       facebook_data: {campaign_id: campaign_id, adset_id: adset_id} )
      end
      before do
        # Required because default scope override in theft_alert
        allow(theft_alert).to receive(:stolen_record) { stolen_record }
        allow(theft_alert).to receive(:facebook_name) { "Test Theft Alert" }
      end

      describe "create_campaign" do
        let(:theft_alert) { TheftAlert.new(id: 12) }
        it "creates a campaign" do
          VCR.use_cassette("facebook/ads_integration-create_campaign", match_requests_on: [:method]) do
            campaign = instance.create_campaign(theft_alert)
            expect(campaign).to be_present
            expect(campaign.id).to be_present
          end
        end
      end

      describe "create_adset" do
        it "creates an adset" do
          expect(theft_alert.campaign_id).to eq campaign_id
          VCR.use_cassette("facebook/ads_integration-create_adset", match_requests_on: [:method]) do
            adset = instance.create_adset(theft_alert)
            expect(adset).to be_present
            expect(adset.id).to be_present
          end
        end
      end

      describe "create_ad, create_for" do
        let(:message) { "Oakland: Keep an eye out for this stolen Surly. If you see it, let the owner know on Bike Index!" }
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
              expect(theft_alert.facebook_post_url).to be_present
            end
          end
        end
      end

      describe "update_facebook_data" do
        let(:facebook_data) { {ad_id: "6250596761214", adset_id: "6250596755814", campaign_id: "6250596474814"} }
        let(:effective_object_story_id) { "500198263370025_4299715976751549" }
        let(:bike) { FactoryBot.create(:bike, :with_stolen_record, :with_ownership_claimed) }
        let(:stolen_record) { bike.current_stolen_record }
        let(:theft_alert) do
          # id: 1633
          TheftAlert.create(theft_alert_plan: theft_alert_plan,
                           stolen_record: stolen_record,
                           user: bike.user,
                           facebook_data: facebook_data)
        end
        let(:target_engagement) { {post: "2", comment: "1", link_click: "4", post_reaction: "1", unique_clicks: "16", page_engagement: "8", post_engagement: "8", landing_page_view: "2"} }
        it "updates and sets the data" do
          expect(theft_alert).to be_valid
          expect(theft_alert.id).to be_present
          expect_hashes_to_match(theft_alert.facebook_data, facebook_data)
          expect(theft_alert.reload.reach).to be_blank
          VCR.use_cassette("facebook/ads_integration-update_facebook_data", match_requests_on: [:method]) do
            instance.update_facebook_data(theft_alert)
            theft_alert.reload
            expect(theft_alert.facebook_data["effective_object_story_id"]).to eq effective_object_story_id
            expect(theft_alert.facebook_data["amount_cents"]).to eq 999
            expect(theft_alert.facebook_data["updated_at"]).to be_within(5).of Time.current.to_i
            expect(theft_alert.facebook_data["spend_cents"]).to eq 649
            expect(theft_alert.reach).to eq 2428
            expect_hashes_to_match(theft_alert.engagement, target_engagement)
          end
        end
        context "with effective_object_story_id present" do
          let(:facebook_data) { {ad_id: "6250596761214", adset_id: "6250596755814", campaign_id: "6250596474814", effective_object_story_id: "500198263370025_4299715976751549"} }
          it "does the same thing" do
            expect(theft_alert.reload.reach).to be_blank
            VCR.use_cassette("facebook/ads_integration-update_facebook_data", match_requests_on: [:method]) do
              instance.update_facebook_data(theft_alert)
              theft_alert.reload
              expect(theft_alert.facebook_data["effective_object_story_id"]).to eq effective_object_story_id
              expect(theft_alert.facebook_data["amount_cents"]).to eq 999
              expect(theft_alert.facebook_data["updated_at"]).to be_within(5).of Time.current.to_i
              expect(theft_alert.facebook_data["spend_cents"]).to eq 649
              expect(theft_alert.reach).to eq 2428
              expect_hashes_to_match(theft_alert.engagement, target_engagement)
            end
          end
        end
      end
    end
  end
end


