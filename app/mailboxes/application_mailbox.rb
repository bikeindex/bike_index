class ApplicationMailbox < ActionMailbox::Base
  # Route emails to marketplace reply mailbox based on the reply-to address format
  # Format: reply+{token}@reply.bikeindex.org
  routing(/^reply\+.+@/i => :marketplace_replies)

  # Catch-all for unmatched emails
  routing all: :catch_all
end
