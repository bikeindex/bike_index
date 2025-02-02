require "rails_helper"

RSpec.describe Integrations::Twilio do
  let(:instance) { described_class.new }

  describe "twilio_formatted" do
    it "strips leading zeros" do
      expect(Integrations::Twilio.twilio_formatted("00100000000")).to eq "100000000"
    end
  end

  describe "send_message" do
    it "sends a message" do
      VCR.use_cassette("twilio_integration-send_message", match_requests_on: [:path]) do
        phone = Phonifyer.phonify "5102223333"
        result = instance.send_message(to: phone, body: "This is a test message")
        expect(result.sid).to be_present
        expect(result.status).to eq "queued"
      end
    end
  end

  describe "send_notification" do
    let(:notification) { FactoryBot.create(:notification, message_channel: "text", kind: "phone_verification") }
    it "sends a message, stores the sid" do
      VCR.use_cassette("twilio_integration-send_notification", match_requests_on: [:path]) do
        expect(notification.twilio_sid).to be_blank
        instance.send_notification(notification, to: "05102224444", body: "This is a test message")
        notification.reload
        expect(notification.twilio_sid).to be_present
        notification.twilio_sid
        expect(notification.delivery_status).to eq "queued"
        expect(notification.message_channel_target).to eq "05102224444"
        # test credentials don't have access to fetch, too lazy to stub
        # instance.send_notification(notification, to: "5102224444", body: "This is a test message")
        # notification.reload
        # expect(notification.twilio_sid).to eq original sid
        # expect(notification.delivery_status).to eq "delivered"
      end
    end
  end
end
