# Adding to prevent things exploding prior to migration
# Remove after PR #1503 merged

class AbandonedRecord < ActiveRecord::Base
end
