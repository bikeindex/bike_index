class ApplicationMailbox < ActionMailbox::Base
  # Anything Postmark forwards to our inbound address (support@, contact@, bugs@, ...) is a
  # support message - capture it for admin triage rather than raising RoutingError and retrying
  routing all: :bug_reports
end
