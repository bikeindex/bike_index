require "spec_helper"

describe TwitterClient do
  it "initializes a singleton" do
    expect(TwitterClient).to respond_to(:instance)
    expect(TwitterClient).to_not respond_to(:new)
  end

  it "delegates class methods to the client instance" do
    client = double("Twitter::REST::Client", status: {}, user_timeline: {})
    allow(Twitter::REST::Client).to receive(:new).and_return(client)

    tweet_id = 133453
    TwitterClient.status(tweet_id)
    expect(client).to have_received(:status).with(tweet_id)

    handle = "sferik"
    TwitterClient.user_timeline(handle)
    expect(client).to have_received(:user_timeline).with(handle)
  end
end
