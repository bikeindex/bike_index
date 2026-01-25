class CatchAllMailbox < ApplicationMailbox
  def process
    # Silently ignore unmatched emails
  end
end
