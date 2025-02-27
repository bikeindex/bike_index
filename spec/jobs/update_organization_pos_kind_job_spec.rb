require "rails_helper"

RSpec.describe UpdateOrganizationPosKindJob, type: :lib do
  let(:described_class) { UpdateOrganizationPosKindJob }
  let(:instance) { described_class.new }
  include_context :scheduled_job
  include_examples :scheduled_job_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority" # overrides default
    expect(described_class.frequency).to be > 6.hours
  end

  describe "perform" do
    let(:og_updated_at) { Time.current - 3.weeks }
    let(:organization) { FactoryBot.create(:organization, kind: "bike_shop", created_at: Time.current - 1.month, updated_at: og_updated_at) }
    let!(:pos_bike) { FactoryBot.create(:bike_ascend_pos, creation_organization: organization) }
    it "schedules all the workers" do
      organization.reload
      pos_bike.reload
      expect(organization.bikes).to eq([pos_bike])
      expect(organization.pos_kind).to eq "no_pos"
      expect {
        instance.perform
      }.to change(described_class.jobs, :count).by(1)
      described_class.drain
      organization.reload
      expect(organization.pos_kind).to eq "ascend_pos"
    end
    context "broken ascend" do
      let(:time) { Time.current - 3.weeks }
      before do
        pos_bike.bulk_import.update(created_at: time)
        organization.update_column :pos_kind, :ascend_pos
      end
      def expect_broken_ascend(org, start_at: Time.current)
        org.reload
        expect(org.pos_kind).to eq "broken_ascend_pos"

        organization_status1 = OrganizationStatus.order(:id).first
        expect(organization_status1.organization_id).to eq organization.id
        expect(organization_status1.pos_kind).to eq "ascend_pos"
        expect(organization_status1.start_at).to be_present
        # expect(organization_status1.start_at).to be_within(5).of Time.current
        expect(organization_status1.end_at).to be_within(5).of start_at

        organization_status2 = OrganizationStatus.order(:id).last
        expect(organization_status2.organization_id).to eq org.id
        expect(organization_status2.pos_kind).to eq "broken_ascend_pos"
        expect(organization_status2.start_at).to be_within(5).of start_at
        expect(organization_status2.end_at).to be_blank
      end
      context "bulk_import_ascend broken" do
        let!(:bulk_import) do
          FactoryBot.create(:bulk_import_ascend,
            organization: organization,
            import_errors: {file: ["Invalid file extension, must be .csv or .tsv"]},
            created_at: Time.current - 3.days)
        end
        it "updates to broken" do
          expect(organization.reload.updated_at).to be_within(5).of og_updated_at
          expect(bulk_import.reload.blocking_error?).to be_truthy
          expect(instance.send(:status_change_at, organization)).to be_within(5).of time
          expect {
            instance.perform(organization.id)
          }.to change(OrganizationStatus, :count).by 2

          expect_broken_ascend(organization, start_at: time)
        end
      end
      context "bike" do
        let!(:pos_bike) { FactoryBot.create(:bike_ascend_pos, creation_organization: organization, created_at: Time.current - 1.month) }
        it "updates to broken" do
          expect(organization.reload.updated_at).to be_within(5).of og_updated_at
          pos_bike.reload
          expect(organization.bikes).to eq([pos_bike])
          expect(organization.pos_kind).to eq "ascend_pos"
          expect {
            instance.perform(organization.id)
          }.to change(OrganizationStatus, :count).by 2

          expect_broken_ascend(organization, start_at: og_updated_at)
        end
      end
    end
    context "deleted" do
      let(:pos_bike) { nil }
      it "creates status" do
        organization.destroy
        expect {
          instance.perform(organization.id)
          instance.perform(organization.id)
        }.to change(OrganizationStatus, :count).by 1

        organization_status1 = OrganizationStatus.order(:id).first
        expect(organization_status1.organization_id).to eq organization.id
        expect(organization_status1.pos_kind).to eq "no_pos"
        expect(organization_status1.start_at).to be_within(5).of Time.current
        expect(organization_status1.end_at).to be_blank
        expect(organization_status1.deleted?).to be_truthy

        organization.restore
        expect {
          instance.perform(organization.id)
        }.to change(OrganizationStatus, :count).by 1

        expect(organization_status1.reload.current?).to be_falsey
        expect(organization_status1.end_at).to be_blank
        expect(organization_status1.deleted?).to be_truthy

        organization_status2 = OrganizationStatus.order(:id).last
        expect(organization_status2.organization_id).to eq organization.id
        expect(organization_status2.pos_kind).to eq "no_pos"
        expect(organization_status2.start_at).to be_within(5).of Time.current
        expect(organization_status2.end_at).to be_blank
        expect(organization_status2.deleted?).to be_falsey
      end
    end
    context "broken lightspeed" do
      let!(:pos_bike) { FactoryBot.create(:bike_lightspeed_pos, creation_organization: organization, created_at: Time.current - 1.month) }
      it "updates to broken" do
        organization.reload
        pos_bike.reload
        expect(organization.bikes).to eq([pos_bike])
        expect(organization.pos_kind).to eq "no_pos"
        instance.perform(organization.id)

        organization.reload
        expect(organization.pos_kind).to eq "broken_lightspeed_pos"
      end
    end
  end

  describe "calculated_pos_kind" do
    context "organization with pos bike and non pos bike" do
      let(:organization) { FactoryBot.create(:organization_with_auto_user, kind: "bike_shop") }
      let!(:bike_pos) { FactoryBot.create(:bike_lightspeed_pos, creation_organization: organization) }
      let!(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization) }
      it "returns pos type" do
        organization.reload
        expect(organization.pos_kind).to eq "no_pos"
        expect(described_class.calculated_pos_kind(organization)).to eq "lightspeed_pos"
        UpdateOrganizationPosKindJob.new.perform(organization.id)
        organization.reload
        expect(organization.pos_kind).to eq "lightspeed_pos"
        # And if bike is created before cut-of for pos kind, it returns broken
        bike_pos.update_attribute :created_at, Time.current - 2.weeks
        expect(described_class.calculated_pos_kind(organization)).to eq "broken_lightspeed_pos"
      end
    end
    context "ascend_name" do
      let(:organization) { FactoryBot.create(:organization, ascend_name: "SOMESHOP") }
      it "returns ascend_pos" do
        expect(organization.reload.pos_kind).to eq "no_pos"
        expect(described_class.calculated_pos_kind(organization)).to eq "ascend_pos"
        expect {
          UpdateOrganizationPosKindJob.new.perform(organization.id)
        }.to change(OrganizationStatus, :count).by 2
        organization.reload
        expect(organization.manual_pos_kind?).to be_blank
        expect(organization.pos_kind).to eq "ascend_pos"
        expect(organization.show_bulk_import?).to be_truthy

        organization_status1 = OrganizationStatus.order(:id).first
        expect(organization_status1.organization_id).to eq organization.id
        expect(organization_status1.pos_kind).to eq "no_pos"
        expect(organization_status1.start_at).to be_within(5).of Time.current
        expect(organization_status1.end_at).to be_within(1).of Time.current

        organization_status2 = OrganizationStatus.order(:id).last
        expect(organization_status2.organization_id).to eq organization.id
        expect(organization_status2.pos_kind).to eq "ascend_pos"
        expect(organization_status2.start_at).to be_within(5).of Time.current
        expect(organization_status2.end_at).to be_blank
      end
    end
    context "manual_pos_kind" do
      let(:organization) { FactoryBot.create(:organization, manual_pos_kind: "lightspeed_pos") }
      it "overrides everything" do
        expect(organization.manual_lightspeed_pos?).to be_truthy
        expect(organization.pos_kind).to eq "no_pos"
        UpdateOrganizationPosKindJob.new.perform(organization.id)
        organization.reload
        expect(organization.manual_pos_kind).to eq "lightspeed_pos"
        expect(organization.pos_kind).to eq "lightspeed_pos"
        organization.update_attribute :manual_pos_kind, "broken_ascend_pos"

        UpdateOrganizationPosKindJob.new.perform(organization.id)
        organization.reload
        expect(organization.manual_pos_kind).to eq "broken_ascend_pos"
        expect(organization.pos_kind).to eq "broken_ascend_pos"
      end
    end
    context "recent bikes" do
      let(:organization) { FactoryBot.create(:organization_with_auto_user, kind: "bike_shop") }
      it "no_pos, does_not_need_pos if older organization" do
        organization.reload
        expect(described_class.calculated_pos_kind(organization)).to eq "no_pos"
        3.times { FactoryBot.create(:bike_organized, creation_organization: organization) }
        organization.reload
        expect(described_class.calculated_pos_kind(organization)).to eq "no_pos"
        expect {
          UpdateOrganizationPosKindJob.new.perform(organization.id)
        }.to change(OrganizationStatus, :count).by 1
        organization_status1 = OrganizationStatus.order(:id).first
        expect(organization_status1.current?).to be_truthy

        organization.update_attribute :created_at, Time.current - 2.weeks
        organization.reload
        expect(described_class.calculated_pos_kind(organization)).to eq "does_not_need_pos"

        expect {
          UpdateOrganizationPosKindJob.new.perform(organization.id)
        }.to change(OrganizationStatus, :count).by 1
        expect(organization_status1.reload.current?).to be_falsey

        organization_status2 = OrganizationStatus.order(:id).last
        expect(organization_status2.organization_id).to eq organization.id
        expect(organization_status2.pos_kind).to eq "does_not_need_pos"
        expect(organization_status2.start_at).to be_within(5).of Time.current
        expect(organization_status2.end_at).to be_blank
      end
    end
  end
end
