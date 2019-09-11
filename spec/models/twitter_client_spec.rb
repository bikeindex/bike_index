require "rails_helper"

RSpec.describe TwitterClient, type: :model do
  it "initializes a singleton" do
    expect(TwitterClient).to respond_to(:instance)
    expect(TwitterClient).to_not respond_to(:new)
  end

  it "delegates class methods to the client instance", vcr: true do
    tweet_id = 1170061123191791622
    status = TwitterClient.status(tweet_id)
    expect(status).to be_an_instance_of(Twitter::Tweet)
    expect(status.id).to eq(tweet_id)

    timeline = TwitterClient.user_timeline("BikeIndexTest")
    expect(timeline).to be_an_instance_of(Array)
    expect(timeline).to all(be_an_instance_of(Twitter::Tweet))
  end
end
