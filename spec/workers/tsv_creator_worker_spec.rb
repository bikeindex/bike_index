require 'spec_helper'

describe TsvCreatorWorker do
  it { is_expected.to be_processed_in :carrierwave }

  it "enqueues another awesome job" do
    TsvCreatorWorker.perform_async
    expect(TsvCreatorWorker).to have_enqueued_job
  end

  it "sends tsv creator the method it's passed" do
    expect_any_instance_of(TsvCreator).to receive(:create_stolen).with(true).and_return(true)
    expect_any_instance_of(TsvCreator).to receive(:create_stolen).with(false).and_return(true)
    TsvCreatorWorker.new.perform('create_stolen', true)
  end

end
