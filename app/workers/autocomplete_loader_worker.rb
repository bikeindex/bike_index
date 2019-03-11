class AutocompleteLoaderWorker
  include Sidekiq::Worker
  sidekiq_options queue: "high_priority", backtrace: true

  def perform(loader_method)
    AutocompleteLoader.new.send(loader_method)
  end
end
