require "twilio-ruby"

class TwilioIntegration
  ACCOUNT_SID = ENV["TWILIO_SID"]
  AUTH_TOKEN = ENV["TWILIO_TOKEN"]

  def client
    @client = Twilio::REST::Client.new ACCOUNT_SID, AUTH_TOKEN
  end
end
