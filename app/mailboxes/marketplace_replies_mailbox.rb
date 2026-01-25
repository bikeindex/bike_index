class MarketplaceRepliesMailbox < ApplicationMailbox
  before_processing :find_original_message

  def process
    return bounce_with_missing_message if @original_message.blank?
    return bounce_with_unauthorized if sender_user.blank?

    create_reply_message
  end

  private

  attr_reader :original_message

  def find_original_message
    @original_message = MarketplaceMessage.find_by(reply_token: reply_token)
  end

  def reply_token
    # Extract token from reply+{token}@reply.bikeindex.org
    mail.to.find { |addr| addr.match?(/^reply\+/i) }&.split("@")&.first&.sub(/^reply\+/i, "")
  end

  def sender_user
    @sender_user ||= User.find_by(email: mail.from.first&.downcase)
  end

  def create_reply_message
    # Determine who the reply should go to
    # If the sender was the original receiver, reply goes to original sender
    # If the sender was the original sender, reply goes to original receiver
    new_receiver = if sender_user.id == @original_message.receiver_id
      @original_message.sender
    elsif sender_user.id == @original_message.sender_id
      @original_message.receiver
    else
      # Sender is not part of this conversation
      return bounce_with_unauthorized
    end

    MarketplaceMessage.create!(
      marketplace_listing: @original_message.marketplace_listing,
      sender: sender_user,
      receiver: new_receiver,
      subject: mail.subject || "Re: #{@original_message.subject}",
      body: extract_reply_body,
      initial_record_id: @original_message.initial_record_id || @original_message.id
    )
  end

  def extract_reply_body
    # Try to get plain text body, fall back to stripping HTML
    mail.text_part&.decoded || mail.body.decoded.gsub(/<[^>]*>/, "").strip
  end

  def bounce_with_missing_message
    # Log the issue but don't send a bounce email to avoid spam
    Rails.logger.warn("MarketplaceRepliesMailbox: Could not find message for token: #{reply_token}")
  end

  def bounce_with_unauthorized
    Rails.logger.warn("MarketplaceRepliesMailbox: Unauthorized sender #{mail.from.first} for token: #{reply_token}")
  end
end
