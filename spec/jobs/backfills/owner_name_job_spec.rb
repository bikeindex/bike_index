require "rails_helper"

RSpec.describe Backfills::OwnerNameJob, type: :job do
  let(:instance) { described_class.new }
  let(:user) { FactoryBot.create(:user_confirmed, name: nil) }
  let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user:) }
  let(:named_bike) { FactoryBot.create(:bike, :with_ownership_claimed) }

  it "fills owner_name from an account that has since been named" do
    expect(bike.reload.owner_name).to be_blank
    expect(named_bike.reload.owner_name).to be_present
    # update_column, as AfterUserChangeJob would otherwise copy the name over itself
    user.update_column :name, "Cardinal Rider"

    Sidekiq::Job.clear_all
    instance.perform
    expect(CallbackJobs::AfterBikeSaveJob.jobs.map { it["args"] }).to eq([[bike.id, true, true]])

    CallbackJobs::AfterBikeSaveJob.drain
    expect(bike.reload.owner_name).to eq "Cardinal Rider"
  end
end
