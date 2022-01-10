require "rails_helper"

RSpec.describe BulkAfterUserChangeWorker, type: :job do
  let(:instance) { described_class.new }

  describe "user_registration_organization" do
    let(:user_registration_organization) { FactoryBot.create(:user_registration_organization, all_bikes: true, registration_info: {student_id: "222"}) }
    let!(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: user) }
    let(:user) { user_registration_organization.user }
    let(:organization) { user_registration_organization.organization }
    let!(:bike2) { FactoryBot.create(:bike_organized, :with_ownership_claimed, user: user) }
    let(:organization2) { bike2.creation_organization }
    it "removes dupes" do
      expect(user.user_registration_organizations.count).to eq 1
      expect(user.user_registration_organizations.pluck(:organization_id).uniq).to eq([organization.id])
      expect(user.bikes.count).to eq 2
      expect(bike.reload.bike_organizations.pluck(:organization_id)).to eq([])
      expect(bike2.reload.bike_organizations.pluck(:organization_id)).to eq([organization2.id])
      Sidekiq::Worker.clear_all
      instance.perform(user.id)
      expect(Sidekiq::Worker.jobs.count).to eq 0
      expect(user.reload.user_registration_organizations.count).to eq 2
      expect(user.pluck(:organization_id)).to match_array([organization.id, organization2.id])
      expect(UserRegistrationOrganization.count).to eq 2
      expect(user.user_registration_organizations.where(organization_id: organization2.id).first.all_bikes).to be_falsey
      expect(bike1.reload.bike_organizations.pluck(:organization_id)).to eq([organization.id])
      expect(bike2.reload.bike_organizations.pluck(:organization_id)).to eq([organization.id, organization2.id])
      expect(bike2.registration_info).to eq({student_id: "222"})
    end
  end
end
