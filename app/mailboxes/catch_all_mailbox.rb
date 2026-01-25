class CatchAllMailbox < ApplicationMailbox
  def process
    # Log unmatched emails for debugging
    Rails.logger.info("CatchAllMailbox: Received unmatched email from #{mail.from.first} to #{mail.to.join(", ")}")
  end
end
