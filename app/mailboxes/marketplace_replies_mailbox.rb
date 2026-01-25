class MarketplaceRepliesMailbox < ApplicationMailbox
  def process
    original_message = self.class.find_original_message(reply_token)
    return if original_message.blank?

    sender = self.class.find_sender(sender_email)
    return if sender.blank?

    receiver = self.class.find_receiver(original_message, sender)
    return if receiver.blank?

    self.class.create_reply(original_message:, sender:, receiver:, subject:, body:)
  end

  class << self
    def find_original_message(reply_token)
      MarketplaceMessage.find_by(reply_token:)
    end

    def find_sender(email)
      User.find_by(email:)
    end

    def find_receiver(original_message, sender)
      case sender.id
      when original_message.receiver_id then original_message.sender
      when original_message.sender_id then original_message.receiver
      end
    end

    def create_reply(original_message:, sender:, receiver:, subject:, body:)
      MarketplaceMessage.create!(
        marketplace_listing: original_message.marketplace_listing,
        sender:,
        receiver:,
        subject: subject.presence || "Re: #{original_message.subject}",
        body:,
        initial_record_id: original_message.initial_record_id || original_message.id
      )
    end
  end

  private

  def reply_token
    mail.to
      .find { |addr| addr.match?(/\Areply\+/i) }
      &.split("@")&.first
      &.sub(/\Areply\+/i, "")
  end

  def sender_email
    mail.from.first&.downcase
  end

  def subject
    mail.subject
  end

  def body
    mail.text_part&.decoded || mail.body.decoded.gsub(/<[^>]*>/, "").strip
  end
end
