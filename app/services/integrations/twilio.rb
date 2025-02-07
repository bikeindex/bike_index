require "twilio-ruby"

class Integrations::Twilio
  ACCOUNT_SID = ENV["TWILIO_SID"]
  AUTH_TOKEN = ENV["TWILIO_TOKEN"]
  OUTGOING_NUMBER = ENV["TWILIO_NUMBER"]

  def self.twilio_formatted(str)
    str.gsub(/\A0+/, "")
  end

  def client
    @client ||= Twilio::REST::Client.new ACCOUNT_SID, AUTH_TOKEN
  end

  def send_message(to:, body:)
    client.messages.create(body: body,
      from: OUTGOING_NUMBER,
      to: self.class.twilio_formatted(to))
  end

  def get_message(sid)
    client.messages(sid).fetch
  end

  def send_notification(notification, to:, body:)
    if notification.twilio_sid.present?
      result = get_message(notification.twilio_sid)
      notification.update(delivery_status_str: result.status)
    else
      result = send_message(to: to, body: body)
      notification.update(message_channel_target: to,
        twilio_sid: result.sid,
        delivery_status_str: result.status)
    end
    result
  end
end
