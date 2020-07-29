require "rails_helper"

RSpec.describe UnusedOwnershipRemovalWorker, type: :job do
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority"
    expect(described_class.frequency).to be > 20.hours
  end

  it "makes non existent ownerships not current" do
    Sidekiq::Worker.clear_all
    ownership = Ownership.create(owner_email: "something@d.com", creator_id: 69, bike_id: 69, current: true)
    expect {
      described_class.perform_async
    }.to change(described_class.jobs, :count).by 1
    described_class.drain
    ownership.reload
    expect(ownership.current).to be_falsey
  end
end
