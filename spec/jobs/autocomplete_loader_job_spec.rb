require "rails_helper"

RSpec.describe AutocompleteLoaderJob, type: :job do
  it "calls AutocompleteLoaderJob", :flaky do
    expect(Autocomplete::Loader).to receive(:clear_redis)
    expect(Autocomplete::Loader).to receive(:load_all)
    AutocompleteLoaderJob.new.perform("clear")
  end
end
