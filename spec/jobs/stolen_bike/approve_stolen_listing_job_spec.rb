require "rails_helper"

RSpec.describe StolenBike::ApproveStolenListingJob, type: :job, vcr: true do
  it "enqueues another awesome job" do
    bike = FactoryBot.create(:bike)
    StolenBike::ApproveStolenListingJob.perform_async(bike.id)
    expect(StolenBike::ApproveStolenListingJob).to have_enqueued_sidekiq_job(bike.id)
  end

  context "given a bike with no current stolen record" do
    it "raises ArgumentError" do
      bike = FactoryBot.create(:bike)
      job = -> { StolenBike::ApproveStolenListingJob.new.perform(bike.id) }
      expect { job.call }.to raise_error(ArgumentError)
    end
  end

  context "given no twitter client" do
    it "raises ArgumentError" do
      bike = FactoryBot.create(:stolen_bike)
      job = -> { StolenBike::ApproveStolenListingJob.new.perform(bike.id) }
      expect { job.call }.to raise_error(ArgumentError)
    end
  end

  # Commented out in #2618 - twitter is disabled
  #
  # context "given a bike with a current stolen record and a nearby twitter account" do
  #   let!(:twitter_account) { FactoryBot.create(:twitter_account_1, :active, :in_nyc) }
  #   let!(:bike) { FactoryBot.create(:stolen_bike) }
  #   it "creates twitter stolen bike alert" do
  #     expect {
  #       StolenBike::ApproveStolenListingJob.new.perform(bike.id)
  #     }.to change(Tweet, :count).by 1
  #   end
  #   it "skips if tweeting disabled" do
  #     stub_const("StolenBike::ApproveStolenListingJob::TWEETING_DISABLED", true)
  #     expect {
  #       StolenBike::ApproveStolenListingJob.new.perform(bike.id)
  #     }.to change(Tweet, :count).by 0
  #   end
  # end
end
