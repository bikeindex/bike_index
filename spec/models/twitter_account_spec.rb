require "rails_helper"

RSpec.describe TwitterAccount, type: :model do
  describe "geocoding" do
    it "geocodes default location correctly without hitting API" do
      twitter_account = TwitterAccount.new
      twitter_account.address = "278 Broadway, New York, NY 10007, USA"
      twitter_account.geocode
      expect(twitter_account.latitude).to eq(40.7143528)
      expect(twitter_account.longitude).to eq(-74.0059731)
    end

    it "should geocode and then reverse geocode on save" do
      twitter_account = FactoryBot.create(:twitter_account, address: "3554 W Shakespeare Ave, Chicago IL 60647")
      expect(twitter_account).to receive(:fetch_account_info).and_return(true)

      twitter_account.save

      expect(twitter_account.latitude).to be_present
      expect(twitter_account.longitude).to be_present
      expect(twitter_account.country).to eq("United States")
      expect(twitter_account.city).to eq("New York")
      expect(twitter_account.state).to eq("NY")
    end
  end

  describe "#fetch_account_info" do
    it "gets the twitter account info" do
      twitter_account = FactoryBot.create(:twitter_account_1, :active)
      account_hash = twitter_account.fetch_account_info
      expect(account_hash[:name]).to be_present
      expect(account_hash[:profile_image_url_https]).to be_present
    end

    it "sets the account info from fetch_account_info" do
      twitter_account = TwitterAccount.new
      expect(twitter_account).to receive(:twitter_user).and_return({ stuff: "foo" })
      twitter_account.fetch_account_info
      expect(twitter_account.twitter_account_info).to eq({ stuff: "foo" })
    end

    it "does nothing if account info is present" do
      twitter_account = TwitterAccount.new(twitter_account_info: { stuff: "foo" })
      twitter_account.fetch_account_info
      expect(twitter_account.twitter_account_info).to eq({ stuff: "foo" })
    end

    it "has a before_save filter" do
      expect(TwitterAccount._save_callbacks.select { |cb| cb.kind.eql?(:before) }.
        map(&:raw_filter).include?(:fetch_account_info)).to be_truthy
    end
  end

  describe "#default_account" do
    it "returns first national account" do
      national_account1 = FactoryBot.create(:twitter_account_1, :national, :active)
      _national_account2 = FactoryBot.create(:twitter_account_1, :national, :active)
      expect(TwitterAccount.default_account).to eq(national_account1)
    end
  end

  describe :default_account_for_country do
    it "finds national account" do
      _default_national = FactoryBot.create(:twitter_account_1, :active, :national, :default)
      national = FactoryBot.create(:twitter_account_2, :active, :national, :canadian)

      national.update_attribute(:country, "Australia")

      expect(TwitterAccount.default_account_for_country("Australia").id).to eq(national.id)
    end

    it "finds default account if no national exists for the country" do
      default = FactoryBot.create(:twitter_account_1, :national, :active, :default)
      national = FactoryBot.create(:twitter_account_2, :national, :active, :canadian)

      national.update_attribute(:country, "Australia")

      expect(TwitterAccount.default_account_for_country("Canada").id).to eq(default.id)
    end
  end
end
