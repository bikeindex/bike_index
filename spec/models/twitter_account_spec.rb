require "rails_helper"

RSpec.describe TwitterAccount, type: :model do
  describe "geocoding" do
    it "geocodes default location correctly without hitting API" do
      twitter_account = FactoryBot.build(:twitter_account)
      twitter_account.geocode
      expect(twitter_account.latitude).to eq(40.7143528)
      expect(twitter_account.longitude).to eq(-74.0059731)
    end

    it "should geocode and then reverse geocode on save" do
      twitter_account = FactoryBot.build(:twitter_account, address: "3554 W Shakespeare Ave, Chicago IL 60647")
      expect(twitter_account).to receive(:fetch_account_info).and_return(true)

      twitter_account.save

      expect(twitter_account.latitude).to be_present
      expect(twitter_account.longitude).to be_present
      expect(twitter_account.country&.name).to eq("United States")
      expect(twitter_account.city).to eq("New York")
      expect(twitter_account.state&.abbreviation).to eq("NY")
    end
  end

  describe "#fetch_account_info" do
    it "gets the twitter account info" do
      twitter_account = FactoryBot.create(:twitter_account_1, :active)

      twitter_account.fetch_account_info

      account_hash = twitter_account.twitter_account_info
      expect(account_hash["name"]).to be_present
      expect(account_hash["profile_image_url_https"]).to be_present
    end

    it "sets the account info from fetch_account_info on save" do
      twitter_account = FactoryBot.build(:twitter_account, twitter_account_info: {})
      expect(twitter_account).to receive(:twitter_user).and_return({ screen_name: "foo", created_at: "Sun Jun 22 20:46:35 +0000 2014" })

      twitter_account.save
      twitter_account.reload
      expect(twitter_account.twitter_account_info).to be_present
      expect(twitter_account.created_at).to be_within(1.second).of Time.at(1403469995)
    end

    it "does nothing if account info is present" do
      twitter_account = FactoryBot.build(:twitter_account, twitter_account_info: { screen_name: "BikeIndex" })
      allow(twitter_account).to receive(:twitter_user).and_return({ screen_name: "foo" })

      twitter_account.fetch_account_info

      expect(twitter_account).to_not have_received(:twitter_user)
      expect(twitter_account.twitter_account_info).to eq("screen_name" => "BikeIndex")
    end
  end

  describe "#default_account" do
    it "returns first national account" do
      national_account1 = FactoryBot.create(:twitter_account_1, :national, :active)
      _national_account2 = FactoryBot.create(:twitter_account_2, :national, :active)
      expect(TwitterAccount.default_account).to eq(national_account1)
    end
  end

  describe "set_error and clear_error" do
    let(:twitter_account) { FactoryBot.create(:twitter_account_1) }
    it "sets the errors" do
      twitter_account.set_error("ffffff")
      twitter_account.reload
      expect(twitter_account.last_error).to eq("ffffff")
      expect(twitter_account.last_error_at).to be_within(1.second).of Time.current
      expect(twitter_account.errored?).to be_truthy
      expect(TwitterAccount.errored.pluck(:id)).to eq([twitter_account.id])
      twitter_account.clear_error
      twitter_account.reload
      expect(twitter_account.last_error).to be_blank
      expect(twitter_account.errored?).to be_falsey
      expect(TwitterAccount.errored.pluck(:id)).to eq([])
    end
  end

  describe :default_account_for_country do
    it "finds national account" do
      _default_national = FactoryBot.create(:twitter_account_1, :active, :national, :default)
      national = FactoryBot.create(:twitter_account_2, :active, :national, :canadian)

      australia = FactoryBot.create(:country_australia)
      national.update_attribute(:country, australia)

      expect(TwitterAccount.default_account_for_country("Australia").id).to eq(national.id)
    end

    it "finds default account if no national exists for the country" do
      default = FactoryBot.create(:twitter_account_1, :national, :active, :default)
      national = FactoryBot.create(:twitter_account_2, :national, :active, :canadian)

      australia = FactoryBot.create(:country_australia)
      national.update_attribute(:country, australia)

      expect(TwitterAccount.default_account_for_country("Canada").id).to eq(default.id)
    end
  end
end
