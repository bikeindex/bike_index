require "rails_helper"

RSpec.describe AutocompleteLoaderJob, type: :job do
  it "calls AutocompleteLoaderJob", :flaky do
    AutocompleteLoaderJob.new.perform("clear")
  end
end
