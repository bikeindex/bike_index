class LoggedSearch < AnalyticsRecord
  ENDPOINT_ENUM = {
    web: 0,
  }

  enum kind: ENDPOINT_ENUM

  validates_presence_of :log_line
  validates_uniqueness_of :request_id, allow_nil: false
end
