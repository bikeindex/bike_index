require "rails_helper"

RSpec.describe SocialPoster::Bluesky do
  let(:stolen_record) { bike.fetch_current_stolen_record if defined?(bike) }
  before do
    stolen_record&.skip_geocoding = false
    stolen_record&.save
  end

  describe "#build_post_text" do
    let(:bike) { FactoryBot.create(:stolen_bike, :blue_trek_930) }
    let(:social_account) { FactoryBot.create(:social_account, :active, :national, platform: :bluesky, consumer_key: nil, consumer_secret: nil, user_secret: nil) }
    let(:poster) { SocialPoster::Bluesky.new(bike) }

    before do
      social_account
    end

    it "creates correct string" do
      result = poster.build_post_text
      expect(result).to start_with("STOLEN - ")
      expect(result).to include("Blue Trek 930")
      expect(result).to include("https://bikeindex.org/bikes/#{bike.id}")
    end

    context "with long model name" do
      let(:manufacturer) { FactoryBot.create(:manufacturer, name: "Specialized") }
      let(:bike) { FactoryBot.create(:stolen_bike, manufacturer:, frame_model: "Turbo Creo 2 Expert Carbon Electric Road Bike") }

      it "truncates appropriately" do
        result = poster.build_post_text
        expect(result.length).to be <= SocialPoster::Bluesky::POST_LENGTH
        expect(result).to include("STOLEN -")
        expect(result).to include("https://bikeindex.org/bikes/#{bike.id}")
      end
    end

    context "found bike" do
      let(:bike) { FactoryBot.create(:bike, :blue_trek_930, status: "status_abandoned") }
      before do
        bike.current_stolen_record&.skip_geocoding = false
        bike.current_stolen_record&.save
      end

      it "uses FOUND prefix" do
        expect(poster.stolen_slug).to eq "FOUND -"
      end
    end
  end

  describe "#create_post" do
    let(:bike) { FactoryBot.create(:stolen_bike) }
    let!(:social_account) do
      FactoryBot.create(:social_account,
        :active,
        :national,
        platform: :bluesky,
        screen_name: "test.bsky.social",
        user_token: "test-app-password",
        consumer_key: nil,
        consumer_secret: nil,
        user_secret: nil)
    end

    context "without social account" do
      before { social_account.destroy }

      it "returns nil" do
        poster = SocialPoster::Bluesky.new(bike)
        expect(poster.create_post).to be_nil
      end
    end

    context "without stolen record" do
      let(:bike) { FactoryBot.create(:bike) }

      it "returns nil" do
        poster = SocialPoster::Bluesky.new(bike)
        expect(poster.create_post).to be_nil
      end
    end
  end

  describe "#compute_max_char" do
    let(:bike) { FactoryBot.create(:stolen_bike) }
    let!(:social_account) { FactoryBot.create(:social_account, :active, :national, platform: :bluesky, consumer_key: nil, consumer_secret: nil, user_secret: nil) }
    let(:poster) { SocialPoster::Bluesky.new(bike) }

    it "calculates max characters correctly" do
      url_length = "https://bikeindex.org/bikes/#{bike.id}".length
      expected = SocialPoster::Bluesky::POST_LENGTH - url_length - "STOLEN -".length - 3
      expect(poster.compute_max_char).to eq expected
    end
  end
end
