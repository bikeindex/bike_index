# frozen_string_literal: true

RSpec.shared_context :caching_enabled do
  RSpec.configure do |config|
    config.around(:each, :caching) do |example|
      ActionController::Base.perform_caching = true
      ActionController::Base.cache_store = cache
      example.run
    ensure
      ActionController::Base.perform_caching = false
      ActionController::Base.cache_store = :null_store
    end
  end
end

RSpec.shared_context :caching_basic do
  include_context :caching_enabled

  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
end

RSpec.shared_context :caching_full do
  include_context :caching_enabled
  let(:cache) { Readthis::Cache.new }
end
