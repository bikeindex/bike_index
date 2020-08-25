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
      expect {
        described_class.new.perform
      }.to change(described_class.jobs, :count).by(1)
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

  describe "organization calculated_pos_kind" do
    context "organization with pos bike and non pos bike" do
      let(:organization) { FactoryBot.create(:organization_with_auto_user, kind: "bike_shop") }
      let!(:bike_pos) { FactoryBot.create(:bike_lightspeed_pos, organization: organization) }
      let!(:bike) { FactoryBot.create(:bike_organized, organization: organization) }
      it "returns pos type" do
        organization.reload
        expect(organization.pos_kind).to eq "no_pos"
        expect(organization.calculated_pos_kind).to eq "lightspeed_pos"
        UpdateOrganizationPosKindWorker.new.perform(organization.id)
        organization.reload
        expect(organization.pos_kind).to eq "lightspeed_pos"
        # And if bike is created before cut-of for pos kind, it returns broken
        bike_pos.update_attribute :created_at, Time.current - 2.weeks
        expect(organization.calculated_pos_kind).to eq "broken_lightspeed_pos"
      end
    end
    context "ascend_name" do
      let(:organization) { FactoryBot.create(:organization, ascend_name: "SOMESHOP") }
      it "returns ascend_pos" do
        expect(organization.calculated_pos_kind).to eq "ascend_pos"
        UpdateOrganizationPosKindWorker.new.perform(organization.id)
        organization.reload
        expect(organization.manual_pos_kind?).to be_blank
        expect(organization.pos_kind).to eq "ascend_pos"
        expect(organization.show_bulk_import?).to be_truthy
      end
    end
    context "manual_pos_kind" do
      let(:organization) { FactoryBot.create(:organization, manual_pos_kind: "lightspeed_pos") }
      it "overrides everything" do
        expect(organization.manual_lightspeed_pos?).to be_truthy
        expect(organization.pos_kind).to eq "no_pos"
        UpdateOrganizationPosKindWorker.new.perform(organization.id)
        organization.reload
        expect(organization.manual_pos_kind).to eq "lightspeed_pos"
        expect(organization.pos_kind).to eq "lightspeed_pos"
        organization.update_attribute :manual_pos_kind, "broken_other_pos"

        UpdateOrganizationPosKindWorker.new.perform(organization.id)
        organization.reload
        expect(organization.manual_pos_kind).to eq "broken_other_pos"
        expect(organization.pos_kind).to eq "broken_other_pos"
      end
    end
    context "recent bikes" do
      let(:organization) { FactoryBot.create(:organization_with_auto_user, kind: "bike_shop") }
      it "no_pos, does_not_need_pos if older organization" do
        organization.reload
        expect(organization.calculated_pos_kind).to eq "no_pos"
        3.times { FactoryBot.create(:bike_organized, organization: organization) }
        organization.reload
        expect(organization.calculated_pos_kind).to eq "no_pos"
        organization.update_attribute :created_at, Time.current - 2.weeks
        organization.reload
        expect(organization.calculated_pos_kind).to eq "does_not_need_pos"
      end
    end
  end
end
