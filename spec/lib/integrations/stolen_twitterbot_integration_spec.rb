require 'spec_helper'

describe StolenTwitterbotIntegration do

  describe :send_tweet do 
    it "sends a post request" do
      ENV['STOLEN_TWITTERBOT_URL'] = 'http://example.com'
      HTTParty.should_receive(:post)
      StolenTwitterbotIntegration.new.send_tweet(101)
    end
  end

end
