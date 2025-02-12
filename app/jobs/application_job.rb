class ApplicationJob
  include Sidekiq::Job
  sidekiq_options queue: "low_priority"
  sidekiq_options backtrace: true
end
