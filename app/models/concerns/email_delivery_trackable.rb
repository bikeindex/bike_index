# frozen_string_literal: true

# For records that own an email's delivery_status. Wrap the delivery in
# track_email_delivery; the record decides what a failure means - and whether it
# raises - in handle_email_delivery_error
module EmailDeliveryTrackable
  extend ActiveSupport::Concern

  # Takes a block, which delivers the email
  def track_email_delivery(is_new_email_address: false)
    return if delivery_settled?

    return update(delivery_status: "delivery_banned") if delivery_email_banned?(is_new_email_address)

    # Only the send is rescued - a ban evaluation that blows up hasn't failed to deliver anything
    begin
      handle_email_delivery_success(yield)
    rescue => e
      handle_email_delivery_error(e)
    end
  end

  private

  def handle_email_delivery_success(delivery)
    update(delivery_status: "delivery_success", message_id: message_id || delivery.try(:message_id))
    nil
  end
end
