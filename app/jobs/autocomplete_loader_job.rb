class AutocompleteLoaderJob < ApplicationJob
  sidekiq_options queue: "high_priority", retry: 1
  PENDING_KEY = "autocomplete_reload_pending"

  # Each reload clears and rebuilds everything, so a batch of manufacturer
  # edits shares one; the key's expiry recovers from a lost job
  def self.enqueue_reload
    perform_in(30.seconds) if RedisPool.conn { |r| r.set(PENDING_KEY, 1, nx: true, ex: 10.minutes.to_i) }
  end

  def perform(kinds_to_reload = nil, print_counts = false)
    RedisPool.conn { |r| r.del(PENDING_KEY) }
    Autocomplete::Loader.clear_redis
    Autocomplete::Loader.load_all(kinds_to_reload, print_counts: print_counts)
  end
end
