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
end
