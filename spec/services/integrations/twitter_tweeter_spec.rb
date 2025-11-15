require "rails_helper"

RSpec.describe Integrations::TwitterTweeter do
  let(:stolen_record) { bike.fetch_current_stolen_record if defined?(bike) }
  before do
    # reverse geocode bike stolen records
    stolen_record&.skip_geocoding = false
    stolen_record&.save
  end

  describe "#build_bike_status" do
    context "stolen bike" do
      let(:bike) { FactoryBot.create(:stolen_bike, :blue_trek_930) }
      let(:default_account) { FactoryBot.create(:social_account_2, :active, :default) }
      let(:social_account) { FactoryBot.create(:social_account_1, :active) }
      let(:tti) { Integrations::TwitterTweeter.new(bike) }
      before do
        expect(bike.current_stolen_record.neighborhood).to eq("Tribeca")
        allow(SocialAccount).to(receive(:in_proximity).and_return([social_account]))
      end
      let(:target) { "STOLEN - Blue Trek 930 in Tribeca https://bikeindex.org/bikes/#{bike.id}" }
      it "creates correct string without media" do
        expect(tti.build_bike_status).to eq target
      end

      context "with manufacturer other" do
        let(:manufacturer_other) { "Really cool manufacturer name" }
        let(:color) { FactoryBot.create(:color, name: "Silver, gray or bare metal") }
        let(:bike) do
          FactoryBot.create(:stolen_bike,
            primary_frame_color: color,
            secondary_frame_color: Color.black,
            manufacturer: Manufacturer.other,
            manufacturer_other: manufacturer_other,
            frame_model: "Bike lyfe")
        end
        let(:target) { "STOLEN - Gray #{manufacturer_other} Bike lyfe in Tribeca https://bikeindex.org/bikes/#{bike.id}" }
        it "does the long manufacturer" do
          expect(tti.build_bike_status).to eq target
        end
      end

      context "Yellow" do
        let(:color) { FactoryBot.create(:color, name: "Yellow or Gold") }
        let(:manufacturer) { FactoryBot.create(:manufacturer, name: "BH Bikes (Beistegui Hermanos)") }
        let(:bike) { FactoryBot.create(:stolen_bike, manufacturer: manufacturer, primary_frame_color: color, frame_model: "ATOMX CARBON LYNX 5.5 PRO") }
        let(:target) { "STOLEN - Yellow BH Bikes ATOMX CARBON LYNX 5.5 PRO in Tribeca https://bikeindex.org/bikes/#{bike.id}" }
        it "simplifies color" do
          expect(tti.build_bike_status).to eq target
        end
      end

      context "with append_block" do
        before { social_account.append_block = "#bikeParty" }
        let(:target) { "STOLEN - Blue Trek 930 in Tribeca https://bikeindex.org/bikes/#{bike.id} #bikeParty" }
        it "creates correct string with append block" do
          expect(tti.build_bike_status).to eq target
        end

        context "long string" do
          # tweet without append block is 68 characters - so frame model needs to be >
          # TWEET_LENGTH - 68 - 10 (#bikeParty) = 202
          let(:color) { FactoryBot.create(:color, name: "Stickers tape or other cover-up") }
          let(:manufacturer) { FactoryBot.create(:manufacturer, name: "Salsa") }
          let(:bike) { FactoryBot.create(:stolen_bike, manufacturer: manufacturer, primary_frame_color: color, frame_model: long_string) }
          let(:long_string) { "Large and sweet MTB, a much longer frame model, because someone put a very long string in here that meanders back and forth and eventually comes to some sort of conclusion but not really! It keeps going" }
          let(:target) { "STOLEN - Stickers Salsa #{long_string} in Tribeca https://bikeindex.org/bikes/#{bike.id}" }
          it "creates correct string without append block if string is too long" do
            expect(tti.build_bike_status).to eq target
          end
        end
      end
    end

    context "bike with image" do
      let(:bike) { FactoryBot.create(:stolen_bike, :blue_trek_930, :with_image) }
      let(:social_account) { FactoryBot.create(:social_account_1, :active) }

      it "creates correct string with media" do
        expect(bike.current_stolen_record.neighborhood).to eq("Tribeca")

        allow(SocialAccount).to(receive(:in_proximity).and_return([social_account]))

        tti = Integrations::TwitterTweeter.new(bike)

        expect(tti.build_bike_status).to(eq <<~STR.strip)
          STOLEN - Blue Trek 930 in Tribeca https://bikeindex.org/bikes/#{bike.id}
        STR
      end
    end
  end

  describe "#create_post" do
    let(:bike) { FactoryBot.create(:stolen_bike) }

    # Commented out in #2618 - twitter is disabled
    #
    # it "posts a text only tweet properly", vcr: true do
    #   social_account = FactoryBot.build(:social_account_1, :active, id: 99)
    #   allow(SocialAccount).to(receive(:in_proximity).and_return([social_account]))

    #   integration = Integrations::TwitterTweeter.new(bike)
    #   tweet = integration.create_tweet

    #   expect(tweet).to be_an_instance_of(Tweet)
    #   expect(integration.reposts&.first).to be_an_instance_of(Tweet)
    #   expect(tweet.platform_response).to be_an_instance_of(Hash)
    #   expect(tweet.postor_avatar).to be_present
    #   expect(tweet.body).to eq "STOLEN - Black Special_name10 in Tribeca https://t.co/6gqhQpUUsC"
    #   expect(tweet.posted_image).to be_blank
    # end

    # it "creates a media tweet with reposts", vcr: true do
    #   expect(bike.current_stolen_record.neighborhood).to eq("Tribeca")

    #   social_account = FactoryBot.build(:social_account_1, :active, id: 99)
    #   secondary_social_account = FactoryBot.build(:social_account_2, :active, id: 9)

    #   allow(SocialAccount).to(receive(:in_proximity).and_return([social_account, secondary_social_account]))

    #   integration = Integrations::TwitterTweeter.new(bike)
    #   expect { integration.create_tweet }.to change { Tweet.count }.by(2)

    #   tweet = integration.post
    #   expect(tweet).to be_an_instance_of(Tweet)
    #   expect(tweet.kind).to eq "stolen_tweet"
    #   expect(integration.reposts.first).to be_an_instance_of(Tweet)
    #   expect(tweet.posted_image).to be_blank # Because this BS is blank, legacy formatting presumably
    # end
  end

  describe "close_social_accounts" do
    let!(:national) { FactoryBot.create(:social_account_1, :national, :active, :default, country: Country.united_states) }
    let(:stolen_bike_bay_area) do
      Bike.new(manual_csr: true,
        current_stolen_record: StolenRecord.new(latitude: 37.8390534, longitude: -122.3114197, country: Country.united_states))
    end
    let(:twitter_tweeter_integration) { Integrations::TwitterTweeter.new(stolen_bike_bay_area) }
    it "returns empty if no location" do
      expect(SocialAccount.in_proximity).to eq([])
      expect(SocialAccount.in_proximity(StolenRecord.new)).to eq([])
      expect(twitter_tweeter_integration.close_social_accounts.map(&:id)).to eq([national.id])
      expect(twitter_tweeter_integration.nearest_social_account&.id).to eq(national.id)
      expect(twitter_tweeter_integration.repostable_accounts.map(&:id)).to eq([])
    end
    context "bay area accounts" do
      include_context :geocoder_real
      let(:twitter_brk) { FactoryBot.create(:social_account, :active, screen_name: "stolenbikesbrk", latitude: 37.8715226, longitude: -122.273042, account_info: {info: true}) }
      let(:twitter_oak) { FactoryBot.create(:social_account, :active, screen_name: "stolenbikesoak", latitude: 37.8043514, longitude: -122.2711639, account_info: {info: true}) }
      let(:twitter_sfo) { FactoryBot.create(:social_account, :active, screen_name: "stolenbikessfo", latitude: 37.7749295, longitude: -122.4194155, account_info: {info: true}) }
      let(:twitter_marin) { FactoryBot.create(:social_account, :active, screen_name: "stolenbikemarin", latitude: 38.06170950000001, longitude: -122.6991484, account_info: {info: true}) }
      let(:twitter_sj) { FactoryBot.create(:social_account, :active, screen_name: "stolenbikessj", latitude: 37.3382082, longitude: -121.8863286, account_info: {info: true}) }
      let(:all_account_ids) { [twitter_brk.id, twitter_oak.id, twitter_sfo.id, twitter_marin.id, twitter_sj.id, national.id] }
      it "matches area accounts" do
        stub_const("Integrations::TwitterTweeter::MAX_REPOST_COUNT", 3)
        expect(all_account_ids.count).to eq 6
        expect(SocialAccount.active.pluck(:id)).to match_array all_account_ids
        expect(SocialAccount.in_proximity(stolen_bike_bay_area.current_stolen_record).map(&:id)).to eq all_account_ids
        expect(twitter_tweeter_integration.close_social_accounts.map(&:id)).to eq all_account_ids
        expect(twitter_tweeter_integration.nearest_social_account&.id).to eq(twitter_brk.id)
        expect(twitter_tweeter_integration.repostable_accounts.map(&:id)).to eq([twitter_oak.id, twitter_sfo.id, twitter_marin.id, twitter_sj.id])

        # With only one near
        stolen_record_sc = StolenRecord.new(latitude: 36.970772, longitude: -121.962723, country: Country.united_states)
        expect(SocialAccount.in_proximity(stolen_record_sc).map(&:id)).to eq([twitter_sj.id, national.id])

        # Sanity check on non-proximity
        stolen_record_la = StolenRecord.new(latitude: 33.992220, longitude: -118.386214, country: Country.united_states)
        expect(SocialAccount.in_proximity(stolen_record_la).map(&:id)).to eq([national.id])

        # Verify that max repost of 0 means 0
        stub_const("Integrations::TwitterTweeter::MAX_REPOST_COUNT", 0)
        expect(twitter_tweeter_integration.repostable_accounts.map(&:id)).to eq([])
      end
    end
  end
end
