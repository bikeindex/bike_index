require 'spec_helper'

describe BikeSaveWorker do
  it { should be_processed_in :updates }

  it "enqueues listing ordering job" do
    BikeSaveWorker.perform_async
    expect(BikeSaveWorker).to have_enqueued_job
  end

end
