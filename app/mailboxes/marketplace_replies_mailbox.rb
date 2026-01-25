class MarketplaceRepliesMailbox < ApplicationMailbox
  def process
    original_message = find_original_message
    return if original_message.blank?

    sender = find_sender
    return if sender.blank?

    receiver = find_receiver(original_message:, sender:)
    return if receiver.blank?

    create_reply(original_message:, sender:, receiver:)
  end

  private

  def find_original_message
    MarketplaceMessage.find_by(reply_token: reply_token)
  end

  def find_sender
    User.find_by(email: mail.from.first&.downcase)
  end

  def find_receiver(original_message:, sender:)
    case sender.id
    when original_message.receiver_id then original_message.sender
    when original_message.sender_id then original_message.receiver
    end
  end

  def create_reply(original_message:, sender:, receiver:)
    MarketplaceMessage.create!(
      marketplace_listing: original_message.marketplace_listing,
      sender:,
      receiver:,
      subject: reply_subject(original_message),
      body: reply_body,
      initial_record_id: original_message.initial_record_id || original_message.id
    )
  end

  def reply_token
    mail.to
      .find { |addr| addr.match?(/\Areply\+/i) }
      &.split("@")&.first
      &.sub(/\Areply\+/i, "")
  end

  def reply_subject(original_message)
    mail.subject.presence || "Re: #{original_message.subject}"
  end

  def reply_body
    mail.text_part&.decoded || mail.body.decoded.gsub(/<[^>]*>/, "").strip
  end

end
