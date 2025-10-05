class ApplicationJob
  include Sidekiq::Job

  sidekiq_options queue: "low_priority", backtrace: true

  def self.skip_env_var
    "SIDEKIQ_SKIP_#{name.underscore.gsub(/\W/, "_").upcase}".freeze
  end

  def skip_job?
    InputNormalizer.boolean(ENV.fetch(self.class.skip_env_var, nil))
  end
end
