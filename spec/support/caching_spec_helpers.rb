# frozen_string_literal: true

RSpec.shared_context :caching_enabled do
  RSpec.configure do |config|
    config.around(:each, :caching) do |example|
      ActionController::Base.perform_caching = true
      ActionController::Base.cache_store = cache
      original_rails_cache = Rails.cache
      Rails.cache = cache
      example.run
    ensure
      ActionController::Base.perform_caching = false
      ActionController::Base.cache_store = :null_store
      Rails.cache = original_rails_cache if original_rails_cache
    end
  end

  # Keys of the fragments a block writes, expanded the way the store sees them. Nothing
  # about the rendered markup says whether it was cached or which parts of the key were
  # there, and a block that writes none rendered entirely from the cache.
  def fragments_written
    keys = []
    subscriber = ActiveSupport::Notifications.subscribe("write_fragment.action_controller") do |_name, _start, _finish, _id, payload|
      keys << ActiveSupport::Cache.expand_cache_key(payload[:key])
    end
    yield
    keys
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
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
