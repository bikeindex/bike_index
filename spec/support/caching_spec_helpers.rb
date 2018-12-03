# frozen_string_literal: true

shared_context :caching_enabled do
  RSpec.configure do |config|
    config.around(:each, :caching) do |example|
      ActionController::Base.perform_caching = true
      ActionController::Base.cache_store = cache
      example.run
      ActionController::Base.perform_caching = false
      ActionController::Base.cache_store = :null_store
    end
  end
end

shared_context :caching_basic do
  include_context :caching_enabled

  class MemoryCacheStore
    def fetch(key)
      return store[key] if store[key]
      store[key] = yield
    end

    def clear
      store.clear
    end

    def store
      @store ||= {}
    end

    def read(key)
      store[key]
    end

    def as_json
      store.as_json
    end
  end

  let(:cache) { MemoryCacheStore.new }
end

shared_context :caching_full do
  include_context :caching_enabled
  let(:cache) { Readthis::Cache.new }
end
