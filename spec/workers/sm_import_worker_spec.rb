require 'spec_helper'

describe SmImportWorker do
  it { should be_processed_in :updates }

  it "enqueues another awesome job" do
    SmImportWorker.perform_async
    expect(SmImportWorker).to have_enqueued_job
  end

end
