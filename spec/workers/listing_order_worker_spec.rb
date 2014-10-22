require 'spec_helper'

describe SmExportWorker do
  it { should be_processed_in :updates }

  it "enqueues listing ordering job" do
    SmExportWorker.perform_async
    expect(SmExportWorker).to have_enqueued_job
  end

end
