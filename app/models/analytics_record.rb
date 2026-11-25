class AnalyticsRecord < ApplicationRecord
  self.abstract_class = true

  # analytics has no replica, but pages served under set_reading_role still read it
  connects_to database: {writing: :analytics, reading: :analytics}
end
