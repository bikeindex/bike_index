# frozen_string_literal: true

module Redlockable
  extend Functionable

  def new_lock_manager
    Redlock::Client.new([Bikeindex::Application.config.redis_default_url])
  end

  def locked?(redlock_key)
    new_lock_manager.locked?(redlock_key)
  end

  def with_redlock(redlock_key, duration_ms: 5.minutes.in_milliseconds.to_i)
    lock_manager = new_lock_manager
    redlock = lock_manager.lock(redlock_key, duration_ms)
    return unless redlock

    begin
      yield
    ensure
      lock_manager.unlock(redlock)
    end
  end
end
