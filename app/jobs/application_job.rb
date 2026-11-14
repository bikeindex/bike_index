class ApplicationJob
  include Sidekiq::Job

  sidekiq_options queue: "low_priority", backtrace: true

  def self.skip_env_var
    "SIDEKIQ_SKIP_#{name.underscore.gsub(/\W/, "_").upcase}".freeze
  end

  def skip_job?
    Binxtils::InputNormalizer.boolean(ENV.fetch(self.class.skip_env_var, nil))
  end

  # One run at a time per id; a run that finds it locked is skipped
  def with_redlock(id, duration: 1.minute)
    lock_manager = Redlock::Client.new([Bikeindex::Application.config.redis_default_url])
    redlock = lock_manager.lock("#{self.class.name}-#{Rails.env.slice(0, 3)}-#{id}", duration.in_milliseconds.to_i)
    return false unless redlock

    begin
      yield
    ensure
      lock_manager.unlock(redlock)
    end
  end
end
