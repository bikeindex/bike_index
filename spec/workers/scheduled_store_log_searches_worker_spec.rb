require "rails_helper"

RSpec.describe ScheduledStoreLogSearchesWorker, type: :job do
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests


end
