Rails.application.config.after_initialize do
  PaperTrail::Version.establish_connection :analytics
end
