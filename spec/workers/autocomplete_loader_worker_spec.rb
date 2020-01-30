require "rails_helper"

RSpec.describe AutocompleteLoaderWorker, type: :job do
  it "is the correct queue" do
    expect(described_class.sidekiq_options["queue"]).to eq "high_priority"
  end

  it "calls passed arguments on autocomplete loader" do
    expect_any_instance_of(AutocompleteLoader).to receive(:clear)
    AutocompleteLoaderWorker.new.perform("clear")
  end
end
