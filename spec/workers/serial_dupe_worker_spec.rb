require 'spec_helper'

describe SerialDupeWorker do
  it { should be_processed_in :stolen }

  it "enqueues listing ordering job" do
    SerialDupeWorker.perform_async
    expect(SerialDupeWorker).to have_enqueued_job
  end

end