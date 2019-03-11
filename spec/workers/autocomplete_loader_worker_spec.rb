require 'spec_helper'

describe AutocompleteLoaderWorker do
  let(:subject) { AutocompleteLoaderWorker }

  it "is the correct queue" do
    expect(subject.sidekiq_options["queue"]).to eq "high_priority"
  end

  it 'calls passed arguments on autocomplete loader' do
    expect_any_instance_of(AutocompleteLoader).to receive(:party)
    AutocompleteLoaderWorker.new.perform('party')
  end
end
