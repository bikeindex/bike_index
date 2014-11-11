require 'spec_helper'

describe UnusedOwnershipRemovalWorker do
  it { should be_processed_in :updates }

  it "enqueues listing ordering job" do
    UnusedOwnershipRemovalWorker.perform_async
    expect(UnusedOwnershipRemovalWorker).to have_enqueued_job
  end

  it "makes non existent ownerships not current" do 
    ownership = Ownership.create(owner_email: 'something@d.com', creator_id: 69, bike_id: 69, current: true)
    UnusedOwnershipRemovalWorker.new.perform(ownership.id)
    ownership.reload.current.should be_false
  end

end
