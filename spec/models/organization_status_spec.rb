require "rails_helper"

RSpec.describe OrganizationStatus, type: :model do
  describe "factory" do
    let(:organization_status) { FactoryBot.create(:organization_status) }
    it "is valid" do
      expect(organization_status).to be_valid
      expect(organization_status.current?).to be_truthy
    end
  end

  describe "at_time" do
    let(:time) { Time.current - 23.hours }
    let!(:organization_status1) { FactoryBot.create(:organization_status, start_at: time - 2.hours, end_at: time - 1.hour) }
    let(:organization) { organization_status1.organization }
    let!(:organization_status2) { FactoryBot.create(:organization_status, organization: organization, start_at: time - 30.minutes) }
    let!(:organization_status3) { FactoryBot.create(:organization_status, start_at: time - 1.minute, end_at: time + 5.minutes) }
    it "returns matching statuses" do
      expect(OrganizationStatus.current.pluck(:id)).to eq([organization_status2.id])
      expect(OrganizationStatus.at_time(time).pluck(:id)).to match_array([organization_status2.id, organization_status3.id])
    end
  end

  describe "find_or_create_current" do
    let(:organization) { FactoryBot.create(:organization, created_at:, updated_at: created_at, pos_kind: "other_pos") }
    let(:created_at) { Time.current - 1.month }
    let(:new_updated_at) { Time.current - 3.hours }
    let(:target_attrs) { {kind: "other", pos_kind: "other_pos", start_at: created_at, end_at: nil, organization_deleted_at: nil} }

    it "returns the current status" do
      expect(organization.reload.created_at).to be_within(1).of created_at
      expect(organization.updated_at).to be_within(1).of created_at
      expect(OrganizationStatus.count).to eq 0
      expect { OrganizationStatus.find_or_create_current(organization) }.to change(OrganizationStatus, :count).by 1

      expect(OrganizationStatus.find_or_create_current(organization)).to match_hash_indifferently target_attrs

      expect { OrganizationStatus.find_or_create_current(organization) }.to change(OrganizationStatus, :count).by 0
      expect(OrganizationStatus.count).to eq 1
    end

    context "when kind is updated kind" do
      it "creates a second status" do
        organization_status1 = OrganizationStatus.find_or_create_current(organization)
        expect(organization_status1).to match_hash_indifferently target_attrs
        organization.update_columns(kind: "bike_shop", updated_at: new_updated_at)

        organization_status2 = OrganizationStatus.find_or_create_current(organization)
        expect(organization_status2.id).to_not eq organization_status1.id
        expect(organization_status2).to match_hash_indifferently target_attrs.merge(kind: "bike_shop", start_at: new_updated_at)

        expect(organization_status1.reload).to match_hash_indifferently target_attrs.merge(end_at: new_updated_at)
      end
    end

    context "with new POS kind, then deletion" do
      it "creates a status" do
        organization_status1 = OrganizationStatus.find_or_create_current(organization)
        expect(organization_status1).to match_hash_indifferently target_attrs
        organization.update_columns(pos_kind: "lightspeed_pos", updated_at: new_updated_at)

        organization_status2 = OrganizationStatus.find_or_create_current(organization)
        expect(organization_status2.id).to_not eq organization_status1.id
        expect(organization_status2).to match_hash_indifferently target_attrs.merge(pos_kind: "lightspeed_pos", start_at: new_updated_at)

        expect(organization_status1.reload).to match_hash_indifferently target_attrs.merge(end_at: new_updated_at)
      end
    end

    context "when organization is deleted" do
      it "ends the existing status" do
        organization_status1 = OrganizationStatus.find_or_create_current(organization)
        expect(organization_status1).to match_hash_indifferently target_attrs
        organization.update_columns(deleted_at: new_updated_at, updated_at: new_updated_at)

        expect do
          OrganizationStatus.find_or_create_current(organization)
          OrganizationStatus.find_or_create_current(organization)
          OrganizationStatus.find_or_create_current(organization)
        end.to_not change(OrganizationStatus, :count)

        # If the organization was briefly undeleted, don't create a new status
        organization.update(deleted_at: new_updated_at + 1.hour)
        expect { OrganizationStatus.find_or_create_current(organization) }.to_not change(OrganizationStatus, :count)

        expect(organization_status1.reload).to match_hash_indifferently target_attrs.merge(end_at: new_updated_at, organization_deleted_at: new_updated_at)

        organization.update(deleted_at: nil)
        expect(organization.reload.deleted?).to be_falsey

        organization_status2 = OrganizationStatus.find_or_create_current(organization)
        expect(organization_status2.id).to_not eq organization_status1.id
        expect(organization_status2).to match_hash_indifferently target_attrs.merge(start_at: organization.updated_at)

        # And the first status isn't updated
        expect(organization_status1.reload).to match_hash_indifferently target_attrs.merge(end_at: new_updated_at, organization_deleted_at: new_updated_at)
        expect(OrganizationStatus.count).to eq 2
      end
    end
  end
end
