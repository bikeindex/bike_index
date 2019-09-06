require "rails_helper"

RSpec.describe ApproveStolenListingWorker, type: :job, vcr: true do
  it "enqueues another awesome job" do
    bike = FactoryBot.create(:bike)
    ApproveStolenListingWorker.perform_async(bike.id)
    expect(ApproveStolenListingWorker).to have_enqueued_sidekiq_job(bike.id)
  end

  context "given a bike with no current stolen record" do
    it "raises ArgumentError" do
      bike = FactoryBot.create(:bike)
      job = -> { ApproveStolenListingWorker.new.perform(bike.id) }
      expect { job.call }.to raise_error(ArgumentError)
    end
  end

  context "given no twitter client" do
    it "raises ArgumentError" do
      bike = FactoryBot.create(:stolen_bike)
      job = -> { ApproveStolenListingWorker.new.perform(bike.id) }
      expect { job.call }.to raise_error(ArgumentError)
    end
  end

  context "given a bike with a current stolen record" do
    it "creates twitter stolen bike alert" do
      FactoryBot.create(:twitter_account_1, :active)
      bike = FactoryBot.create(:stolen_bike)
      ApproveStolenListingWorker.new.perform(bike.id)
    end
  end
end
