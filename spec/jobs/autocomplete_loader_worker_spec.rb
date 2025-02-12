require "rails_helper"

RSpec.describe AutocompleteLoaderWorker, type: :job do
  it "calls AutocompleteLoaderWorker", :flaky do
    expect(Autocomplete::Loader).to receive(:clear_redis)
    expect(Autocomplete::Loader).to receive(:load_all)
    AutocompleteLoaderWorker.new.perform("clear")
  end
end
