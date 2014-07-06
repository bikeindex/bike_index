require 'spec_helper'

describe RecoveryWorker do
  it { should be_processed_in :updates }

  it "enqueues another awesome job" do
    RecoveryWorker.perform_async
    expect(RecoveryWorker).to have_enqueued_job
  end

end
