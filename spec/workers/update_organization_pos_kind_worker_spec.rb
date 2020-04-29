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
    let!(:pos_bike) { FactoryBot.create(:bike_ascend_pos, organization: organization) }
    it "schedules all the workers" do
      organization.reload
      pos_bike.reload
      expect(organization.bikes).to eq([pos_bike])
      expect(organization.pos_kind).to eq "no_pos"
      expect do
        described_class.new.perform
      end.to change(described_class.jobs, :count).by(1)
      described_class.drain
      organization.reload
      expect(organization.pos_kind).to eq "ascend_pos"
    end
    context "broken ascend" do
      let!(:pos_bike) { FactoryBot.create(:bike_ascend_pos, organization: organization, created_at: Time.current - 1.month) }
      it "updates to broken" do
        organization.reload
        pos_bike.reload
        expect(organization.bikes).to eq([pos_bike])
        expect(organization.pos_kind).to eq "no_pos"
        described_class.new.perform(organization.id)

        organization.reload
        expect(organization.pos_kind).to eq "broken_other_pos"
      end
    end
    context "broken lightspeed" do
      let!(:pos_bike) { FactoryBot.create(:bike_lightspeed_pos, organization: organization, created_at: Time.current - 1.month) }
      it "updates to broken" do
        organization.reload
        pos_bike.reload
        expect(organization.bikes).to eq([pos_bike])
        expect(organization.pos_kind).to eq "no_pos"
        described_class.new.perform(organization.id)

        organization.reload
        expect(organization.pos_kind).to eq "broken_lightspeed_pos"
      end
    end
  end
end
