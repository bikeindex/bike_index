class ApplicationMailbox < ActionMailbox::Base
  routing(/(?:bugs|contact)@/i => :bug_reports)
end
