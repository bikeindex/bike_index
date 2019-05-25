require "spec_helper"

describe ApproveStolenListingWorker do
  it "enqueues another awesome job" do
    bike = FactoryBot.create(:bike)
    ApproveStolenListingWorker.perform_async(bike.id)
    expect(ApproveStolenListingWorker).to have_enqueued_sidekiq_job(bike.id)
  end

  it "calls stolen twitterbot integration" do
    expect_any_instance_of(StolenTwitterbotIntegration).to receive(:send_tweet).with(111)
    ApproveStolenListingWorker.new.perform(111)
  end
end
