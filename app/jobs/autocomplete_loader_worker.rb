class AutocompleteLoaderWorker < ApplicationWorker
  sidekiq_options queue: "high_priority", retry: 1

  def perform(kinds_to_reload = nil, print_counts = false)
    Autocomplete::Loader.clear_redis
    Autocomplete::Loader.load_all(kinds_to_reload, print_counts: print_counts)
  end
end
