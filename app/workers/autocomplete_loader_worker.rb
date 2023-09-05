class AutocompleteLoaderWorker < ApplicationWorker
  sidekiq_options queue: "high_priority", retry: 1

  def perform(loader_method)
    AutocompleteLoader.new.send(loader_method)
  end
end
