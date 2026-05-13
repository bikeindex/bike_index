require "active_support/cache"

# Cache store that writes to two backends and reads from one. Used to migrate
# Rails.cache from one backend to another without dropping cached data: deploy
# with the new store as `secondary` to warm it, then flip CACHE_PRIMARY_STORE
# to make it `primary`, then remove the wrapper.
#
# Secondary failures are logged and swallowed so an unhealthy secondary cannot
# take down the request path.
class DualWriteCacheStore < ActiveSupport::Cache::Store
  attr_reader :primary, :secondary

  def initialize(primary:, secondary:, **options)
    super(**options)
    @primary = primary
    @secondary = secondary
  end

  def fetch(name, options = nil, &block)
    if block_given?
      primary.fetch(name, options) do |key|
        value = yield(key)
        safe_secondary { secondary.write(name, value, options) }
        value
      end
    else
      primary.fetch(name, options)
    end
  end

  def fetch_multi(*names, &block)
    options = names.last.is_a?(Hash) ? names.pop : nil
    args = options ? names + [options] : names
    primary.fetch_multi(*args) do |key|
      value = yield(key)
      safe_secondary { secondary.write(key, value, options) }
      value
    end
  end

  def read(name, options = nil)
    primary.read(name, options)
  end

  def read_multi(*names)
    primary.read_multi(*names)
  end

  def exist?(name, options = nil)
    primary.exist?(name, options)
  end

  def write(name, value, options = nil)
    safe_secondary { secondary.write(name, value, options) }
    primary.write(name, value, options)
  end

  def write_multi(hash, options = nil)
    safe_secondary { secondary.write_multi(hash, options) }
    primary.write_multi(hash, options)
  end

  def delete(name, options = nil)
    safe_secondary { secondary.delete(name, options) }
    primary.delete(name, options)
  end

  def delete_multi(names)
    safe_secondary { secondary.delete_multi(names) }
    primary.delete_multi(names)
  end

  def delete_matched(matcher, options = nil)
    safe_secondary { secondary.delete_matched(matcher, options) } if secondary.respond_to?(:delete_matched)
    primary.delete_matched(matcher, options) if primary.respond_to?(:delete_matched)
  end

  def increment(name, amount = 1, options = nil)
    args = options ? [name, amount, options] : [name, amount]
    safe_secondary { secondary.increment(*args) }
    primary.increment(*args)
  end

  def decrement(name, amount = 1, options = nil)
    args = options ? [name, amount, options] : [name, amount]
    safe_secondary { secondary.decrement(*args) }
    primary.decrement(*args)
  end

  def clear(options = nil)
    safe_secondary { secondary.clear(options) }
    primary.clear(options)
  end

  def cleanup(options = nil)
    safe_secondary { secondary.cleanup(options) } if secondary.respond_to?(:cleanup)
    primary.cleanup(options) if primary.respond_to?(:cleanup)
  end

  private

  def safe_secondary
    yield
  rescue => e
    Rails.logger&.warn("[DualWriteCacheStore] secondary failed: #{e.class}: #{e.message}")
    nil
  end
end
