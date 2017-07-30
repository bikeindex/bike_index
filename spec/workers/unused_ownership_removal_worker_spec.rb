require 'spec_helper'

describe UnusedOwnershipRemovalWorker do
  it { is_expected.to be_processed_in :afterwards }

  it 'enqueues listing ordering job' do
    UnusedOwnershipRemovalWorker.perform_async
    expect(UnusedOwnershipRemovalWorker).to have_enqueued_sidekiq_job
  end

  it 'makes non existent ownerships not current' do
    ownership = Ownership.create(owner_email: 'something@d.com', creator_id: 69, bike_id: 69, current: true)
    UnusedOwnershipRemovalWorker.new.perform(ownership.id)
    expect(ownership.reload.current).to be_falsey
  end
end
