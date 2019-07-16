require "rails_helper"

RSpec.describe UpdateOrganizationPosKindWorker, type: :lib do
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority" # overrides default
    expect(described_class.frequency).to be > 6.hours
  end

  describe "perform" do
    let(:organization) { FactoryBot.create(:organization, kind: "bike_shop") }
    let!(:ascend_bike) { FactoryBot.create(:bike_ascend_pos, organization: organization) }
    it "schedules all the workers" do
      organization.reload
      ascend_bike.reload
      expect(organization.bikes).to eq([ascend_bike])
      expect(organization.pos_kind).to eq "no_pos"
      described_class.new.perform
      organization.reload
      expect(organization.pos_kind).to eq "ascend_pos"
    end
  end
end
