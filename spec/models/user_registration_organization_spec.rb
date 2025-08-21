# == Schema Information
#
# Table name: user_registration_organizations
#
#  id                   :bigint           not null, primary key
#  all_bikes            :boolean          default(FALSE)
#  can_not_edit_claimed :boolean          default(FALSE)
#  deleted_at           :datetime
#  registration_info    :jsonb
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  organization_id      :bigint
#  user_id              :bigint
#
# Indexes
#
#  index_user_registration_organizations_on_organization_id  (organization_id)
#  index_user_registration_organizations_on_user_id          (user_id)
#
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
    let(:ownership_registration_info) do
      {
        bike_sticker: "9998888",
        phone: "1112224444",
        student_id: "XXZZUUU",
        organization_affiliation: "community_member"
      }.merge(default_location_registration_address).as_json
    end
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: user, creation_registration_info: ownership_registration_info) }
    let(:target_universal_info) do
      ownership_registration_info.except("bike_sticker")
        .merge("phone" => "3334445555").as_json
    end
    let(:ownership1) { bike.current_ownership }
    let(:user_registration_organization) do
      FactoryBot.create(:user_registration_organization,
        organization: organization,
        user: user,
        all_bikes: true,
        can_edit_claimed: true,
        registration_info: {
          latitude: 23,
          longitude: 44,
          phone: "3334445555" # Note: This clobbers the ownership phone.
        })
    end
    it "updates with the correct registration_info" do
      expect(ownership1.reload.organization_id).to be_blank
      expect(ownership1.owner_name).to eq "Name Goes Here"
      expect(ownership1.registration_info.keys).to match_array ownership_registration_info.as_json.keys
      expect(user_registration_organization.reload.all_bikes).to be_truthy
      expect(user_registration_organization.registration_info).to eq({latitude: 23, longitude: 44, phone: "3334445555"}.as_json)
      expect(UserRegistrationOrganization.org_ids_with_uniq_info(user)).to eq([])
      expect(UserRegistrationOrganization.universal_registration_info_for(user.reload)).to eq target_universal_info
      ownership1.update(updated_at: Time.current)
      expect(ownership1.reload.registration_info).to eq target_universal_info.merge("bike_sticker" => "9998888")
    end
    context "with an organization with reg_organization_affiliation and reg_student_id" do
      let(:organization2) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[reg_organization_affiliation reg_student_id]) }
      let!(:bike2) { FactoryBot.create(:bike_organized, :with_ownership_claimed, user: user, creation_organization: organization2, can_edit_claimed: false) }
      let(:user_registration_organization2) do
        FactoryBot.create(:user_registration_organization,
          all_bikes: false,
          organization: organization2,
          user: user,
          can_edit_claimed: true,
          registration_info: {phone: "9999"})
      end
      let(:target_universal_info) do
        ownership_registration_info.except("student_id", "organization_affiliation", "bike_sticker")
          .merge("phone" => "9998887777",
            "student_id_#{organization2.id}" => "XXZZUUU",
            "organization_affiliation_#{organization2.id}" => "community_member")
          .as_json
      end
      let(:ownership2) { bike2.current_ownership }
      it "updates with the correct thing" do
        user.update(phone: "999 888 - 7777")
        expect(organization2.reload.enabled_feature_slugs).to match_array(%w[reg_organization_affiliation reg_student_id])
        expect(bike.reload.registration_info).to be_present
        expect(bike.organizations.pluck(:id)).to eq([])
        expect(bike2.reload.organizations.pluck(:id)).to eq([organization2.id])
        bike2_organization2 = bike2.bike_organizations.first
        expect(bike2_organization2.overridden_by_user_registration?).to be_falsey
        expect(bike2_organization2.can_edit_claimed).to be_falsey
        expect(ownership2.reload.registration_info).to be_blank

        expect(user_registration_organization.all_bikes).to be_truthy
        expect(user_registration_organization.bikes.pluck(:id)).to match_array([bike.id, bike2.id])
        expect(user_registration_organization2.all_bikes).to be_falsey
        expect(user_registration_organization2.bikes.pluck(:id)).to eq([bike2.id])
        user.reload
        expect(UserRegistrationOrganization.org_ids_with_uniq_info(user)).to eq([organization2.id])
        expect(UserRegistrationOrganization.universal_registration_info_for(user.reload)).to eq target_universal_info

        ownership1.update(updated_at: Time.current)
        expect(ownership1.reload.registration_info).to eq target_universal_info.merge("bike_sticker" => "9998888")
        expect(bike.reload.organizations.pluck(:id)).to eq([organization.id])
        bike_organization = bike.bike_organizations.first
        expect(bike_organization.overridden_by_user_registration?).to be_truthy
        expect(bike_organization.can_edit_claimed).to be_truthy
        expect(bike.bike_organizations.first.can_edit_claimed).to be_truthy

        expect(ownership2.overridden_by_user_registration?).to be_truthy
        ownership2.update(updated_at: Time.current)
        expect(ownership2.reload.registration_info).to eq target_universal_info
        expect(bike2.organizations.pluck(:id)).to match_array([organization.id, organization2.id])
        bike2_organization = bike2.bike_organizations.where(organization_id: organization.id).first

        expect(bike2_organization.overridden_by_user_registration?).to be_truthy
        expect(bike2_organization.can_edit_claimed).to be_truthy
        # Because all_bikes isn't true, this isn't updated
        expect(bike2_organization2.overridden_by_user_registration?).to be_falsey
        expect(bike2_organization2.can_edit_claimed).to be_falsey
      end
      it "still works if the bike_organization is deleted" do
        user.update(phone: "999 888 - 7777")
        expect(organization2.reload.enabled_feature_slugs).to match_array(%w[reg_organization_affiliation reg_student_id])
        expect(bike.reload.registration_info).to be_present
        expect(ownership2.reload.registration_info).to be_blank
        expect(bike2.bike_organizations.count).to eq 1
        bike2.bike_organizations.first.destroy
        expect(bike2.reload.bike_organizations.count).to eq 0
        expect(user_registration_organization.all_bikes).to be_truthy
        expect(user_registration_organization2.all_bikes).to be_falsey
        user.reload
        expect(UserRegistrationOrganization.org_ids_with_uniq_info(user)).to eq([organization2.id])
        expect(UserRegistrationOrganization.universal_registration_info_for(user.reload)).to eq target_universal_info
        expect(ownership2.overridden_by_user_registration?).to be_truthy
        ownership2.update(updated_at: Time.current)
        expect(ownership2.reload.registration_info).to eq target_universal_info
        ownership1.update(updated_at: Time.current)
        expect(ownership1.reload.registration_info).to eq target_universal_info.merge("bike_sticker" => "9998888")
        expect(bike.reload.organizations.pluck(:id)).to eq([organization.id])
        expect(bike2.organizations.pluck(:id)).to eq([organization.id])
      end
    end
  end
end
