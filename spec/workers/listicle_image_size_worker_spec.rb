require 'spec_helper'

describe ListicleImageSizeWorker do
  it { should be_processed_in :carrierwave }
  it { should be_unique }

  it "enqueues another awesome job" do
    ListicleImageSizeWorker.perform_async
    expect(ListicleImageSizeWorker).to have_enqueued_job
  end

end
