require "rails_helper"

RSpec.describe RemoveUnconfirmedUsersWorker, type: :job do
  let(:instance) { described_class.new }
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority"
    expect(described_class.frequency).to be > 20.hours
  end

  describe "perform" do
    context "with unconfirmed users" do
      let!(:confirmed_old) { FactoryBot.create(:user_confirmed, created_at: Time.current - 1.week) }
      let!(:unconfirmed_old) { FactoryBot.create(:user, created_at: Time.current - 1.week) }
      let!(:unconfirmed) { FactoryBot.create(:user) }
      it "removes old unconfirmed" do
        expect(instance.unconfirmed_to_remove.pluck(:id)).to eq([unconfirmed_old.id])
        expect do
          instance.perform
        end.to change(User.unscoped, :count).by(-1)
      end
    end
  end
end
