# frozen_string_literal: true

# Disable Rack::Attack throttling by default in test to avoid
# interfering with request specs. Include :rack_attack context
# to test throttling behavior.
Rack::Attack.enabled = false

RSpec.shared_context :rack_attack do
  around do |example|
    Rack::Attack.cache.store.clear
    Rack::Attack.enabled = true
    example.run
  ensure
    Rack::Attack.enabled = false
    Rack::Attack.cache.store.clear
  end

  # Rack::Attack throttles use fixed wall-clock windows -- the cache key is
  # floor(Time.now / period) -- so a window boundary can roll over mid-example
  # and reset the counter. Firing 2 * limit + 1 requests guarantees that, even
  # if one rollover splits them across two windows, one window still exceeds
  # `limit` (the larger half is always >= limit + 1). The whole batch runs in
  # well under a throttle period, so at most one rollover can happen. This
  # makes a 429 deterministic without freezing time.
  #
  # The block makes one request and returns its response; the first throttled
  # response is returned for further assertions (retry-after, body, etc).
  def rack_attack_throttled_response(limit:)
    responses = Array.new(2 * limit + 1) { yield }
    # The first `limit` requests can never be throttled: each request's
    # window count is at most its index, so index <= limit stays <= limit.
    expect(responses.first(limit).map(&:status)).to all(be < 429)
    throttled = responses.find { |response| response.status == 429 }
    expect(throttled).to be_present
    throttled
  end
end
