class ApplicationMailbox < ActionMailbox::Base
  routing all: :bug_reports
end
