Rails.application.config.after_initialize do
  PaperTrail::Version.establish_connection :analytics
  # analytics has no replica, but pages served under set_reading_role still read versions
  ActiveRecord::Base.connection_handler.establish_connection(:analytics,
    owner_name: PaperTrail::Version.name, role: ActiveRecord.reading_role)
end
