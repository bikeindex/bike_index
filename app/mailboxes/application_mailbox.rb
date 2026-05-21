class ApplicationMailbox < ActionMailbox::Base
  routing(/bugs@/i => :bugs)
end
