require "rails_helper"

RSpec.describe UserRegistrationOrganization, type: :model do
  it_behaves_like "registration_infoable"

  describe "factories" do
    let(:user_registration_organization) { FactoryBot.create(:user_registration_organization) }
    it "is valid" do
      expect(user_registration_organization).to be_valid
      expect(user_registration_organization.all_bikes?).to be_falsey
      expect(user_registration_organization.manages_information?).to be_falsey
    end
  end

  describe "manages_information?" do
    let!(:user_registration_organization) { FactoryBot.create(:user_registration_organization, registration_info: {student_id: "fadf"}) }
    it "is truthy" do
      expect(user_registration_organization.reload.registration_info).to be_present
      expect(user_registration_organization.all_bikes?).to be_falsey
      expect(user_registration_organization.manages_information?).to be_truthy
    end
    context "organization with registration fields" do
      let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["reg_organization_affiliation"]) }
      let!(:user_registration_organization) { FactoryBot.create(:user_registration_organization, organization: organization) }
      it "is truthy" do
        expect(user_registration_organization.reload.registration_info).to be_blank
        expect(user_registration_organization.all_bikes?).to be_truthy
        expect(user_registration_organization.manages_information?).to be_truthy
      end
    end
  end

  describe "registration_info and ownership registration_info" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:user) { FactoryBot.create(:user, name: "Name Goes Here") }
    let(:all_bikes) { true }
    let(:user_registration_organization) do
      FactoryBot.create(:user_registration_organization,
        organization: organization,
        user: user,
        all_bikes: all_bikes,
        can_edit_claimed: true,
        registration_info: {
          latitude: 23,
          longitude: 44,
          phone: "333 444 5555", # Note: This clobbers the ownership phone.
        })
    end
    let(:ownership_registration_info) do
      {
        user_name: "George",
        bike_sticker: "9998888",
        phone: "1112224444",
        student_id: "XXZZUUU",
        organization_affiliation: "employee",
      }.merge(default_location_registration_address).as_json
    end
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: user, creation_registration_info: ownership_registration_info) }
    let(:target_universal_info) do
      ownership_registration_info.except("student_id", "organization_affiliation", "bike_sticker", "user_name")
        .merge("phone" => "3334445555",
          "student_id_#{organization.id}" => "1222",
          "organization_affiliation_#{organization.id}" => "employee")
        .as_json
    end
    let(:ownership) { bike.current_ownership }
    it "updates with the correct registration_info" do
      expect(ownership.reload.organization_id).to be_blank
      expect(ownership.owner_name).to eq "Name Goes Here"
      expect(ownership.registration_info.keys).to match_array ownership_registration_info.as_json.keys
      expect(user_registration_organization.registration_info).to eq({latitude: 23, longitude: 44, phone: "333 444 5555"}.as_json)
      expect(UserRegistrationOrganization.org_ids_with_uniq_info(user)).to eq([organization.id])
      universal_info = UserRegistrationOrganization.universal_registration_info_for(user.reload)
      pp universal_info
      expect(universal_info).to eq ownership_registration_info.merge("phone" => "1112224444")
      # expect(user_registration_organization.reload.registration_info.keys).to match_array(%[phone latitude longitude])
      # expect(UserRegistrationOrganization.)
    end
  end
end
