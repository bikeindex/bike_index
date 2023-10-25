class LoggedSearch < AnalyticsRecord
  ENDPOINT_ENUM = {
    web: 0
  }

  enum kind: ENDPOINT_ENUM
end
