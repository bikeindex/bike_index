require "rails_helper"

RSpec.describe Facebook::AdsIntegration do
  let(:instance) { described_class.new }

  # Not set up to run on CI currently
  if !ENV["CI"] && Facebook::AdsIntegration::TOKEN.present?
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
      let(:stolen_record) { StolenRecord.new(bike: bike, latitude: 37.8297171, longitude: -122.2803456, city: "Oakland") }
      let(:theft_alert) do
        TheftAlert.new(id: 12, theft_alert_plan: theft_alert_plan,
          stolen_record: stolen_record,
          facebook_data: {campaign_id: campaign_id, adset_id: adset_id})
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

      describe "create_ad" do
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
    end
  end
end
