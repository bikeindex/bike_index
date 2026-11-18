class ApplicationJob
  include Sidekiq::Job

  sidekiq_options queue: "low_priority", backtrace: true

  def self.skip_env_var
    "SIDEKIQ_SKIP_#{name.underscore.gsub(/\W/, "_").upcase}".freeze
  end

  def self.redlock_key(id) = "#{name}-#{Rails.env.slice(0, 3)}-#{id}"

  def self.new_lock_manager = Redlock::Client.new([Bikeindex::Application.config.redis_default_url])

  def self.locked_for?(id) = new_lock_manager.locked?(redlock_key(id))

  def skip_job?
    Binxtils::InputNormalizer.boolean(ENV.fetch(self.class.skip_env_var, nil))
  end

  # One run at a time per id: a run that finds it locked is skipped, and returns false
  def with_redlock(id, duration: 1.minute)
    lock_manager = self.class.new_lock_manager
    redlock = lock_manager.lock(self.class.redlock_key(id), duration.in_milliseconds.to_i)
    return false unless redlock

    begin
      yield
    ensure
      lock_manager.unlock(redlock)
    end
  end
end
