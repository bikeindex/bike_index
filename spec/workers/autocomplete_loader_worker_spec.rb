require 'spec_helper'

describe AutocompleteLoaderWorker do
  it { is_expected.to be_processed_in :updates }

  it 'calls passed arguments on autocomplete loader' do
    expect_any_instance_of(AutocompleteLoader).to receive(:party)
    AutocompleteLoaderWorker.new.perform('party')
  end
end
