require "rails_helper"

RSpec.describe SocialAccount, type: :model do
  it_behaves_like "geocodeable"

  describe "geocoding" do
    it "geocodes default location correctly without hitting API" do
      social_account = FactoryBot.build(:social_account, :in_nyc)
      social_account.bike_index_geocode
      expect(social_account.latitude).to eq(40.7143528)
      expect(social_account.longitude).to eq(-74.0059731)
      expect(social_account.city).to eq("New York")
      expect(social_account.state&.abbreviation).to eq("NY")
      expect(social_account.country&.name).to eq("United States")
    end

    it "should geocode and then reverse geocode on save" do
      social_account = FactoryBot.build(
        :social_account,
        :in_chicago,
        skip_geocoding: false,
        state: nil
      )
      social_account.address_string = "1 New Address"
      expect(social_account).to be_should_be_geocoded
      expect(social_account).to be_should_be_reverse_geocoded

      expect(social_account).to receive(:fetch_account_info)
      expect(social_account).to receive(:bike_index_geocode).once
      expect(social_account).to receive(:reverse_geocode).once

      social_account.save
    end
  end

  describe "#fetch_account_info" do
    it "gets the twitter account info" do
      social_account = FactoryBot.create(:social_account_1, :active)

      social_account.fetch_account_info

      account_hash = social_account.social_account_info
      expect(account_hash["name"]).to be_present
      expect(account_hash["profile_image_url_https"]).to be_present
    end

    it "sets the account info from fetch_account_info on save" do
      social_account = FactoryBot.build(:social_account, social_account_info: {})
      expect(social_account).to receive(:twitter_user).and_return({screen_name: "foo", created_at: "Sun Jun 22 20:46:35 +0000 2014"})

      social_account.save
      social_account.reload
      expect(social_account.social_account_info).to be_present
      expect(social_account.created_at).to be_within(1.second).of Time.at(1403469995)
    end

    it "does nothing if account info is present" do
      social_account = FactoryBot.build(:social_account, social_account_info: {screen_name: "BikeIndex"})
      allow(social_account).to receive(:twitter_user).and_return({screen_name: "foo"})

      social_account.fetch_account_info

      expect(social_account).to_not have_received(:twitter_user)
      expect(social_account.social_account_info).to eq("screen_name" => "BikeIndex")
    end
  end

  describe "#default_account" do
    it "returns first national account" do
      national_account1 = FactoryBot.create(:social_account_1, :national, :active)
      _national_account2 = FactoryBot.create(:social_account_2, :national, :active)
      expect(SocialAccount.default_account).to eq(national_account1)
    end
  end

  describe "set_error and clear_error" do
    let(:social_account) { FactoryBot.create(:social_account_1) }
    it "sets the errors" do
      social_account.set_error("ffffff")
      social_account.reload
      expect(social_account.last_error).to eq("ffffff")
      expect(social_account.last_error_at).to be_within(1.second).of Time.current
      expect(social_account.errored?).to be_truthy
      expect(SocialAccount.errored.pluck(:id)).to eq([social_account.id])
      social_account.clear_error
      social_account.reload
      expect(social_account.last_error).to be_blank
      expect(social_account.errored?).to be_falsey
      expect(SocialAccount.errored.pluck(:id)).to eq([])
      expect(SocialAccount.friendly_find("#{social_account.screen_name.upcase}  ")).to eq social_account
      expect(SocialAccount.friendly_find(social_account.id.to_s)).to eq social_account
    end
  end

  describe :default_account_for_country do
    it "finds national account" do
      _default_national = FactoryBot.create(:social_account_1, :active, :national, :default)
      national = FactoryBot.create(:social_account_2, :active, :national, :in_vancouver)

      australia = FactoryBot.create(:country_australia)
      national.update_attribute(:country, australia)

      expect(SocialAccount.default_account_for_country("Australia").id).to eq(national.id)
    end

    it "finds default account if no national exists for the country" do
      default = FactoryBot.create(:social_account_1, :national, :active, :default)
      national = FactoryBot.create(:social_account_2, :national, :active, :in_vancouver)

      australia = FactoryBot.create(:country_australia)
      national.update_attribute(:country, australia)

      expect(SocialAccount.default_account_for_country("Canada").id).to eq(default.id)
    end
  end

  it "delegates class methods to the client instance", vcr: true do
    FactoryBot.create(:social_account_1, :national, :active, :default)
    tweet_id = 1170061123191791622
    status = SocialAccount.get_tweet(tweet_id)
    expect(status).to be_an_instance_of(Twitter::Tweet)
    expect(status.id).to eq(tweet_id)
  end
end
