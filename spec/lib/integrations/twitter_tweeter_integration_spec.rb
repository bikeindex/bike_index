require "rails_helper"

RSpec.describe TwitterTweeterIntegration do
  before do
    # reverse geocode bike stolen records
    stolen_record = bike.current_stolen_record
    stolen_record.skip_geocoding = false
    stolen_record.save
  end

  describe "#build_bike_status" do
    context "stolen bike" do
      let(:bike) { FactoryBot.create(:stolen_bike, :blue_trek_930) }
      let(:default_account) { FactoryBot.create(:twitter_account_2, :active, :default) }
      let(:twitter_account) { FactoryBot.create(:twitter_account_1, :active) }

      it "creates correct string without media" do
        expect(bike.current_stolen_record.neighborhood).to eq("Tribeca")
        allow(bike.current_stolen_record)
          .to(receive(:twitter_accounts_in_proximity).and_return([twitter_account]))

        tti = TwitterTweeterIntegration.new(bike)

        expect(tti.build_bike_status).to(eq <<~STR.strip)
          STOLEN - Blue Trek 930 in Tribeca https://bikeindex.org/bikes/#{bike.id}
        STR
      end

      it "creates correct string with append block" do
        expect(bike.current_stolen_record.neighborhood).to eq("Tribeca")

        twitter_account.append_block = "#bikeParty"
        allow(bike.current_stolen_record)
          .to(receive(:twitter_accounts_in_proximity).and_return([twitter_account]))

        tti = TwitterTweeterIntegration.new(bike)
        status = tti.build_bike_status

        twitter_account.append_block = nil
        expect(status).to(eq <<~STR.strip)
          STOLEN - Blue Trek 930 in Tribeca https://bikeindex.org/bikes/#{bike.id} #bikeParty
        STR
      end

      it "creates correct string without append block if string is too long" do
        expect(bike.current_stolen_record.neighborhood).to eq("Tribeca")

        twitter_account.append_block = "#bikeParty"
        bike.update(frame_model: "Large and sweet MTB, a much longer frame model")
        allow(bike.current_stolen_record)
          .to(receive(:twitter_accounts_in_proximity).and_return([twitter_account]))

        tti = TwitterTweeterIntegration.new(bike)
        status = tti.build_bike_status

        twitter_account.append_block = nil
        expect(status).to(eq <<~STR.strip)
          STOLEN - Blue Trek Large and sweet MTB, a much longer frame model in Tribeca https://bikeindex.org/bikes/#{bike.id}
        STR
      end
    end

    context "recovered bike" do
      let(:bike) { FactoryBot.create(:recovered_bike, :green_novara_torero) }

      it "creates correct string without append block if string is too long" do
        expect(bike.current_stolen_record.neighborhood).to eq("Tribeca")

        _default_account = FactoryBot.build(:twitter_account_2, :active, :default)
        twitter_account = FactoryBot.build(:twitter_account_1, :active)
        allow(bike.current_stolen_record)
          .to(receive(:twitter_accounts_in_proximity).and_return([twitter_account]))

        twitter_account.append_block = "#bikeParty"
        tti = TwitterTweeterIntegration.new(bike)
        status = tti.build_bike_status

        twitter_account.append_block = nil
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
      integration.create_tweet

      expect(integration.tweet).to be_an_instance_of(Tweet)
      expect(integration.retweets&.first).to be_an_instance_of(Twitter::Tweet)
    end

    it "creates a media tweet with retweets", vcr: true do
      expect(bike.current_stolen_record.neighborhood).to eq("Tribeca")

      twitter_account = FactoryBot.build(:twitter_account_1, :active, id: 99)
      secondary_twitter_account = FactoryBot.build(:twitter_account_2, :active, id: 9)

      expect(bike.current_stolen_record).to(receive(:twitter_accounts_in_proximity)
        .and_return([twitter_account, secondary_twitter_account]))

      integration = TwitterTweeterIntegration.new(bike)
      expect { integration.create_tweet }.to change { Tweet.count }.by(2)

      expect(integration.tweet).to be_an_instance_of(Tweet)
      expect(integration.retweets.first).to be_an_instance_of(Twitter::Tweet)
    end
  end
end
