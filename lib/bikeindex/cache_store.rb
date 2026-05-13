require_relative "../dual_write_cache_store"

# Factory that builds Rails.cache for the dual-write Redis → Solid Cache
# migration. Reads CACHE_PRIMARY_STORE to decide which backend serves reads:
#
#   CACHE_PRIMARY_STORE=redis  (default) — read Redis, dual-write to Solid
#   CACHE_PRIMARY_STORE=solid           — read Solid, dual-write to Redis
#   CACHE_PRIMARY_STORE=redis_only      — single store, no dual-write
#   CACHE_PRIMARY_STORE=solid_only      — single store, no dual-write
#
# Once Solid Cache is serving reads with no regressions, set CACHE_PRIMARY_STORE
# to solid_only and remove this wrapper.
module Bikeindex
  module CacheStore
    module_function

    def build(redis_url:)
      mode = ENV.fetch("CACHE_PRIMARY_STORE", "redis").to_sym
      redis = redis_store(redis_url)
      solid = solid_store

      return redis if mode == :redis_only
      return solid if mode == :solid_only

      primary, secondary = (mode == :solid) ? [solid, redis] : [redis, solid]
      DualWriteCacheStore.new(primary:, secondary:)
    end

    def redis_store(url)
      ActiveSupport::Cache.lookup_store(:redis_cache_store, url:)
    end

    def solid_store
      ActiveSupport::Cache.lookup_store(:solid_cache_store)
    end
  end
end
