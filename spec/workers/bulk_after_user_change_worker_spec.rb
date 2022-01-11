require "rails_helper"

RSpec.describe BulkAfterUserChangeWorker, type: :job do
  let(:instance) { described_class.new }

  describe "user_registration_organization" do
    let(:organization) { FactoryBot.create(:organization_with_organization_features) }
    let!(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: organization, creation_registration_info: {student_id: "222"}) }
    let(:user) { bike.user }
    let!(:bike2) { FactoryBot.create(:bike_organized, :with_ownership_claimed, user: user) }
    let!(:bike3) { FactoryBot.create(:bike, :with_ownership_claimed, user: user) }
    let(:organization2) { bike2.creation_organization }
    let(:target_registration_info) { {"student_id" => "222", "student_id_#{organization.id}" => "222"} }
    it "noops" do
      expect(user.user_registration_organizations.count).to eq 0
      expect(user.bikes.count).to eq 3
      expect(bike.reload.bike_organizations.pluck(:organization_id)).to eq([organization.id])
      expect(bike2.reload.bike_organizations.pluck(:organization_id)).to eq([organization2.id])
      expect(bike3.reload.bike_organizations.pluck(:organization_id)).to eq([])
      Sidekiq::Worker.clear_all
      instance.perform(user.id)
      expect(Sidekiq::Worker.jobs.count).to eq 0
      expect(user.reload.user_registration_organizations.count).to eq 0
    end
    context "user updated_at before" do
      it "removes dupes" do
        user.update_column :updated_at, described_class.migration_at - 1.day
        expect(user.user_registration_organizations.count).to eq 0
        expect(user.bikes.count).to eq 3
        expect(bike.reload.bike_organizations.pluck(:organization_id)).to eq([organization.id])
        expect(bike2.reload.bike_organizations.pluck(:organization_id)).to eq([organization2.id])
        expect(bike3.reload.bike_organizations.pluck(:organization_id)).to eq([])
        Sidekiq::Worker.clear_all
        instance.perform(user.id)
        expect(Sidekiq::Worker.jobs.count).to eq 0
        expect(user.reload.user_registration_organizations.count).to eq 2
        user_registration_organization = user.user_registration_organizations.where(organization_id: organization.id).first
        expect(user_registration_organization.all_bikes?).to be_truthy
        expect(user_registration_organization.set_initial_registration_info).to eq target_registration_info
        user_registration_organization2 = user.user_registration_organizations.where(organization_id: organization2.id).first
        expect(user_registration_organization2.all_bikes?).to be_falsey
        expect(user_registration_organization2.bikes.pluck(:id)).to eq([bike2.id])
        expect(user_registration_organization2.bikes.pluck(:id)).to eq([bike2.id])
        expect(UserRegistrationOrganization.count).to eq 2 # Sanity check

        expect(bike.reload.bike_organizations.pluck(:organization_id)).to eq([organization.id])
        expect(bike.registration_info).to eq target_registration_info

        expect(bike2.reload.bike_organizations.pluck(:organization_id)).to match_array([organization.id, organization2.id])
        expect(bike2.registration_info).to eq target_registration_info

        expect(bike3.reload.bike_organizations.pluck(:organization_id)).to eq([organization.id])
        expect(bike3.registration_info).to eq target_registration_info
      end
    end
  end
end
