Rails.application.config.after_initialize do
  PaperTrail::Version.establish_connection :analytics
  # Not an AnalyticsRecord, so it takes AnalyticsRecord's reading role by hand
  ActiveRecord::Base.connection_handler.establish_connection(:analytics,
    owner_name: PaperTrail::Version.name, role: ActiveRecord.reading_role)
end
