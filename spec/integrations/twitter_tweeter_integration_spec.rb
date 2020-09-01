require "rails_helper"

RSpec.describe TwitterTweeterIntegration do
  before do
    # reverse geocode bike stolen records
    stolen_record = bike.fetch_current_stolen_record
    stolen_record.skip_geocoding = false
    stolen_record.save
  end

  describe "#build_bike_status" do
    context "stolen bike" do
      let(:bike) { FactoryBot.create(:stolen_bike, :blue_trek_930) }
      let(:default_account) { FactoryBot.create(:twitter_account_2, :active, :default) }
      let(:twitter_account) { FactoryBot.create(:twitter_account_1, :active) }
      let(:tti) { TwitterTweeterIntegration.new(bike) }
      before do
        expect(bike.current_stolen_record.neighborhood).to eq("Tribeca")
        allow(bike.current_stolen_record)
          .to(receive(:twitter_accounts_in_proximity).and_return([twitter_account]))
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
        before { twitter_account.append_block = "#bikeParty" }
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

    context "recovered bike" do
      let(:bike) { FactoryBot.create(:recovered_bike, :green_novara_torero) }

      it "creates correct string without append block if string is too long" do
        expect(bike.current_stolen_record.neighborhood).to eq("Tribeca")

        _default_account = FactoryBot.build(:twitter_account_2, :active, :default)
        twitter_account = FactoryBot.build(:twitter_account_1, :active)
        bike.update_column :status, "status_abandoned"
        bike.reload
        expect(bike.status_abandoned?).to be_truthy
        allow(bike.current_stolen_record)
          .to(receive(:twitter_accounts_in_proximity).and_return([twitter_account]))

        twitter_account.append_block = "#bikeParty"
        tti = TwitterTweeterIntegration.new(bike)
        status = tti.build_bike_status

        twitter_account.append_block = nil
        expect(tti.stolen_slug).to eq "FOUND -"
        expect(status).to(eq <<~STR.strip)
          FOUND - Green Novara Torero 29" in Tribeca https://bikeindex.org/bikes/#{bike.id} #bikeParty
        STR
      end
    end

    context "bike with image" do
      let(:bike) { FactoryBot.create(:stolen_bike, :blue_trek_930, :with_image) }
      let(:twitter_account) { FactoryBot.create(:twitter_account_1, :active) }

      it "creates correct string with media" do
        expect(bike.current_stolen_record.neighborhood).to eq("Tribeca")

        allow(bike.current_stolen_record)
          .to(receive(:twitter_accounts_in_proximity).and_return([twitter_account]))

        tti = TwitterTweeterIntegration.new(bike)

        expect(tti.build_bike_status).to(eq <<~STR.strip)
          STOLEN - Blue Trek 930 in Tribeca https://bikeindex.org/bikes/#{bike.id}
        STR
      end
    end
  end

  describe "#create_tweet" do
    let(:bike) { FactoryBot.create(:stolen_bike) }

    it "posts a text only tweet properly", vcr: true do
      twitter_account = FactoryBot.build(:twitter_account_1, :active, id: 99)
      expect(bike.current_stolen_record).to(receive(:twitter_accounts_in_proximity)
        .and_return([twitter_account]))

      integration = TwitterTweeterIntegration.new(bike)
      tweet = integration.create_tweet

      expect(tweet).to be_an_instance_of(Tweet)
      expect(integration.retweets&.first).to be_an_instance_of(Tweet)
      expect(tweet.twitter_response).to be_an_instance_of(Hash)
      expect(tweet.tweetor_avatar).to be_present
      expect(tweet.body).to eq "STOLEN - Black Special_name10 in Tribeca https://t.co/6gqhQpUUsC"
      expect(tweet.tweeted_image).to be_blank
    end

    it "creates a media tweet with retweets", vcr: true do
      expect(bike.current_stolen_record.neighborhood).to eq("Tribeca")

      twitter_account = FactoryBot.build(:twitter_account_1, :active, id: 99)
      secondary_twitter_account = FactoryBot.build(:twitter_account_2, :active, id: 9)

      expect(bike.current_stolen_record).to(receive(:twitter_accounts_in_proximity)
        .and_return([twitter_account, secondary_twitter_account]))

      integration = TwitterTweeterIntegration.new(bike)
      expect { integration.create_tweet }.to change { Tweet.count }.by(2)

      tweet = integration.tweet
      expect(tweet).to be_an_instance_of(Tweet)
      expect(tweet.kind).to eq "stolen_tweet"
      expect(integration.retweets.first).to be_an_instance_of(Tweet)
      expect(tweet.tweeted_image).to be_blank # Because this BS is blank, legacy formatting presumably
    end
  end
end
