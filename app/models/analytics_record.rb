class AnalyticsRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :analytics }
end
