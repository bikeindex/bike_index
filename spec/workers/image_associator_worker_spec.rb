require 'spec_helper'

describe ImageAssociatorWorker do
  it { should be_processed_in :image_associator }

  it "enqueues another awesome job" do
    ImageAssociatorWorker.perform_async
    expect(ImageAssociatorWorker).to have_enqueued_job
  end

end
