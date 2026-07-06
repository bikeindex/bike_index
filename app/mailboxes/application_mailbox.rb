class ApplicationMailbox < ActionMailbox::Base
  routing(/bugs@/i => :bug_reports)
end
