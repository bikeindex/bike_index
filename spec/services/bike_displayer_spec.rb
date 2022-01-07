require "rails_helper"

RSpec.describe BikeDisplayer do
  describe "show_paint_description?" do
    let(:black) { Color.black }
    it "returns false" do
      expect(BikeDisplayer.paint_description?(Bike.new)).to be_falsey
    end
    context "with paint" do
      let(:stickers) { FactoryBot.create(:color, name: "Stickers tape or other cover-up") }
      let(:paint) { FactoryBot.create(:paint, name: "812348123") }
      let(:bike) { FactoryBot.create(:bike, paint: paint, primary_frame_color: black) }
      it "returns false" do
        expect(BikeDisplayer.paint_description?(bike)).to be_falsey
      end
      context "bike pos" do
        it "returns true" do
          allow(bike).to receive(:pos?) { true }
          expect(bike.render_paint_description?).to be_truthy
          # If the primary frame color isn't black, don't render
          bike.primary_frame_color = stickers
          expect(bike.render_paint_description?).to be_falsey
          bike.primary_frame_color = black # reset to black
          expect(BikeDisplayer.paint_description?(bike)).to be_truthy
          # And with a secondary frame color it is truthy
          bike.secondary_frame_color = stickers
          expect(BikeDisplayer.paint_description?(bike)).to be_truthy
        end
      end
    end
    context "pos registration without paint" do
      let(:bike) { FactoryBot.create(:bike_lightspeed_pos, primary_frame_color: black, paint: nil) }
      it "returns false" do
        expect(BikeDisplayer.paint_description?(bike)).to be_falsey
      end
    end
  end

  describe "display_impound_claim?" do
    let(:bike) { Bike.new }
    let(:admin) { User.new(superuser: true) }
    let(:owner) { User.new }
    before { allow(bike).to receive(:owner) { owner } }
    it "is falsey if bike doesn't have impounded" do
      expect(BikeDisplayer.display_impound_claim?(bike)).to be_falsey
    end
    context "impound bike" do
      let(:impound_record) { ImpoundRecord.new(bike: bike) }
      before { allow(bike).to receive(:current_impound_record) { impound_record } }
      it "is truthy" do
        expect(BikeDisplayer.display_impound_claim?(bike)).to be_truthy
        expect(BikeDisplayer.display_impound_claim?(bike, User.new)).to be_truthy
        expect(BikeDisplayer.display_impound_claim?(bike, admin)).to be_truthy
        expect(BikeDisplayer.display_impound_claim?(bike, owner)).to be_falsey
      end
    end
    context "impound_claim for bike" do
      let(:owner) { FactoryBot.create(:user_confirmed) }
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: owner) }
      let!(:impound_claim) { FactoryBot.create(:impound_claim_with_stolen_record, bike: bike, user: owner) }
      let(:bike_claimed) { impound_claim.bike_claimed }
      it "is expected values" do
        bike.reload
        expect(bike.authorized?(owner)).to be_truthy
        expect(impound_claim.resolved?).to be_falsey
        expect(impound_claim.bike_submitting&.id).to eq bike.id
        expect(bike.impound_claims_submitting.pluck(:id)).to eq([impound_claim.id])
        expect(BikeDisplayer.display_impound_claim?(bike)).to be_falsey
        expect(BikeDisplayer.display_impound_claim?(bike, User.new)).to be_falsey
        expect(BikeDisplayer.display_impound_claim?(bike, admin)).to be_falsey
        expect(BikeDisplayer.display_impound_claim?(bike, owner)).to be_falsey
        expect(bike_claimed.id).to_not eq bike.id
        expect(BikeDisplayer.display_impound_claim?(bike_claimed)).to be_truthy
      end
      context "retrieved" do
        let(:impound_record) { FactoryBot.create(:impound_record_resolved, status: "retrieved_by_owner", bike: bike) }
        let(:organization) { impound_record.organization }
        let!(:impound_claim) do
          FactoryBot.create(:impound_claim_resolved, :with_stolen_record,
            bike: bike,
            user: owner,
            impound_record: impound_record,
            organization: organization)
        end
        it "is expected values" do
          bike.reload
          impound_claim.reload
          expect(impound_claim.resolved?).to be_truthy
          expect(bike.authorized?(owner)).to be_truthy
          expect(bike.current_impound_record_id).to be_blank
          expect(impound_claim.user_id).to eq owner.id
          expect(impound_claim.bike_submitting&.id).to eq bike.id
          expect(bike.impound_claims_submitting.pluck(:id)).to eq([impound_claim.id])
          expect(BikeDisplayer.display_impound_claim?(bike)).to be_falsey
          expect(BikeDisplayer.display_impound_claim?(bike, User.new)).to be_falsey
          expect(BikeDisplayer.display_impound_claim?(bike, admin)).to be_falsey
          expect(BikeDisplayer.display_impound_claim?(bike, owner)).to be_falsey

          expect(impound_claim.bike_submitting.id).to eq bike_claimed.id
          expect(BikeDisplayer.display_impound_claim?(bike_claimed)).to be_falsey
          expect(BikeDisplayer.display_impound_claim?(bike_claimed, User.new)).to be_falsey
          expect(BikeDisplayer.display_impound_claim?(bike_claimed, admin)).to be_falsey
          expect(BikeDisplayer.display_impound_claim?(bike_claimed, owner)).to be_falsey
        end
      end
    end
  end

  describe "display_contact_owner?" do
    let(:bike) { Bike.new }
    let(:admin) { User.new(superuser: true) }
    let(:owner) { User.new }
    before { allow(bike).to receive(:owner) { owner } }
    it "is falsey if bike doesn't have stolen record" do
      expect(bike.contact_owner?).to be_falsey
      expect(bike.contact_owner?(User.new)).to be_falsey
      expect(bike.contact_owner?(admin)).to be_truthy
      expect(BikeDisplayer.display_contact_owner?(bike)).to be_falsey
    end
    context "stolen bike" do
      let(:bike) { Bike.new(status: "status_stolen", current_stolen_record: StolenRecord.new) }
      it "is truthy" do
        expect(bike.contact_owner?).to be_falsey
        expect(bike.contact_owner?(User.new)).to be_truthy
        expect(BikeDisplayer.display_contact_owner?(bike)).to be_truthy
        expect(BikeDisplayer.display_contact_owner?(bike, admin)).to be_truthy
        expect(BikeDisplayer.display_contact_owner?(bike, owner)).to be_truthy
      end
    end
  end

  describe "display_sticker_edit?" do
    let(:bike) { Bike.new }
    let(:owner) { User.new }
    it "is falsey" do
      allow(bike).to receive(:owner) { owner }
      expect(BikeDisplayer.display_sticker_edit?(bike, owner)).to be_falsey
      expect(BikeDisplayer.display_sticker_edit?(bike, User.new(superuser: true))).to be_truthy
    end
    context "organization is a bike_sticker child" do
      let!(:organization_regional_child) { FactoryBot.create(:organization, :in_nyc) }
      let(:enabled_feature_slugs) { %w[regional_bike_counts bike_stickers] }
      let!(:organization_regional_parent) { FactoryBot.create(:organization_with_regional_bike_counts, :in_nyc, enabled_feature_slugs: enabled_feature_slugs) }
      let(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: organization_regional_child, can_edit_claimed: false) }
      let(:owner) { bike.owner }
      let(:bike2) { FactoryBot.create(:bike, :with_ownership_claimed, user: owner) }
      let(:bike3) { FactoryBot.create(:bike, :with_ownership_claimed) }
      let!(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, user: member, bike: bike3, organization: organization_regional_parent) }
      let(:member) { FactoryBot.create(:user, :with_organization, organization: organization_regional_parent) }
      before do
        organization_regional_parent.update(updated_at: Time.current)
        organization_regional_child.reload
        organization_regional_child.update(updated_at: Time.current)
        organization_regional_child.reload
        expect(Organization.regional.pluck(:id)).to eq([organization_regional_parent.id])
        expect(organization_regional_child.regional_parents.pluck(:id)).to eq([organization_regional_parent.id])
      end
      it "is falsey" do
        expect(organization_regional_child.enabled_feature_slugs).to eq(%w[bike_stickers reg_bike_sticker])
        bike.reload
        expect(bike.organizations.pluck(:id)).to eq([organization_regional_child.id])
        expect(BikeDisplayer.display_sticker_edit?(bike, owner)).to be_falsey
        # Organization member can edit bike stickers
        expect(BikeDisplayer.display_sticker_edit?(bike, member)).to be_truthy
        expect(BikeDisplayer.display_sticker_edit?(bike, FactoryBot.create(:user))).to be_falsey
        # Test that another bike of the user, without the organization, is falsey
        bike2.reload
        expect(bike2.organizations.pluck(:id)).to eq([])
        expect(BikeDisplayer.display_sticker_edit?(bike2, owner)).to be_falsey
        # test that adding a sticker from the organization, is still falsey
        bike3.reload
        expect(bike3.bike_stickers.pluck(:organization_id)).to eq([organization_regional_parent.id])
        expect(BikeStickerUpdate.where(bike_id: bike3.id).pluck(:bike_sticker_id)).to eq([bike_sticker.id])
        expect(bike_sticker.reload.user_editable?).to be_falsey
        expect(bike3.owner).to be_present
        expect(BikeDisplayer.display_sticker_edit?(bike3, bike3.owner)).to be_falsey
      end
      context "organization has bike_stickers_user" do
        let(:enabled_feature_slugs) { %w[regional_bike_counts bike_stickers bike_stickers_user_editable] }
        it "is truthy" do
          expect(organization_regional_child.enabled_feature_slugs).to eq(%w[bike_stickers bike_stickers_user_editable reg_bike_sticker])
          bike.reload
          expect(bike.organizations.pluck(:id)).to eq([organization_regional_child.id])
          expect(BikeDisplayer.display_sticker_edit?(bike, owner)).to be_truthy
          # Organization member can edit bike stickers
          expect(BikeDisplayer.display_sticker_edit?(bike, member)).to be_truthy
          expect(BikeDisplayer.display_sticker_edit?(bike, FactoryBot.create(:user))).to be_falsey
          # Test that another bike of the user, without the organization, is truthy
          bike2.reload
          expect(bike2.organizations.pluck(:id)).to eq([])
          expect(BikeDisplayer.display_sticker_edit?(bike2, owner)).to be_truthy
          # test that adding a sticker from the organization, is still truthy
          bike3.reload
          expect(bike3.bike_stickers.pluck(:organization_id)).to eq([organization_regional_parent.id])
          expect(bike_sticker.reload.user_editable?).to be_truthy
          expect(bike3.owner).to be_present
          expect(BikeDisplayer.display_sticker_edit?(bike3, bike3.owner)).to be_truthy
        end
      end
    end
    context "bike has sticker, other user bike has sticker" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
      let(:owner) { bike.owner }
      let!(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, bike: bike) }
      let(:bike2) { FactoryBot.create(:bike, :with_ownership_claimed, user: owner) }
      let(:bike_other) { FactoryBot.create(:bike) }
      it "is truthy" do
        bike.reload
        expect(bike.owner).to eq owner
        expect(bike.bike_stickers.pluck(:id)).to eq([bike_sticker.id])
        expect(BikeDisplayer.display_sticker_edit?(bike, owner)).to be_truthy
        bike2.reload
        expect(bike2.owner).to eq owner
        expect(bike2.bike_stickers.pluck(:id)).to eq([])
        expect(BikeDisplayer.display_sticker_edit?(bike2, owner)).to be_truthy
        bike_sticker.claim(bike: bike_other)
        bike.reload
        expect(bike.bike_stickers.pluck(:id)).to eq([])
        expect(BikeDisplayer.display_sticker_edit?(bike, owner)).to be_truthy
        bike2.reload
        expect(BikeDisplayer.display_sticker_edit?(bike2, owner)).to be_truthy
      end
    end
    context "user can't add more stickers" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
      let(:owner) { bike.owner }
      let!(:bike_sticker) { FactoryBot.create(:bike_sticker) }
      let(:user2) { FactoryBot.create(:user_confirmed) }
      let(:bike2) { FactoryBot.create(:bike) }
      it "is falsey" do
        bike_sticker.claim(user: owner, bike: bike)
        expect(BikeSticker.where(user_id: owner.id).pluck(:id)).to eq([bike_sticker.id])
        # Test that it's based on updates, not actual bike/sticker ownership
        bike_sticker.claim(user: user2, bike: bike2)
        bike_sticker.reload
        expect(BikeSticker.where(user_id: owner.id).pluck(:id)).to eq([])
        expect(BikeStickerUpdate.where(user_id: owner.id).pluck(:bike_sticker_id)).to eq([bike_sticker.id])
        owner.reload
        expect(owner.authorized?(bike_sticker.bike)).to be_falsey
        expect(owner.bike_sticker_updates.count).to eq 1
        expect(BikeDisplayer.display_sticker_edit?(bike, owner)).to be_truthy
        stub_const("BikeSticker::MAX_UNORGANIZED", 2)
      end
    end
  end

  describe "user_edit_bike_address?, display_edit_address_fields? and edit_street_address?" do
    let(:bike) { FactoryBot.create(:bike) }
    let(:user) { FactoryBot.create(:user, :confirmed) }
    let(:admin) { FactoryBot.create(:admin) }

    it "is falsey" do
      expect(BikeDisplayer.display_edit_address_fields?(bike, user)).to be_falsey
      expect(BikeDisplayer.user_edit_bike_address?(bike, user)).to be_falsey
    end
    context "new bike" do
      let(:bike) { Bike.new }
      it "is truthy" do
        expect(BikeDisplayer.display_edit_address_fields?(bike, user)).to be_truthy
        expect(BikeDisplayer.user_edit_bike_address?(bike, user)).to be_truthy
      end
    end
    context "owner" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership, creator: user) }
      it "is falsey for owner" do
        expect(bike.reload.creator&.id).to eq user.id
        expect(bike.reload.owner&.id).to eq user.id
        expect(bike.reload.authorized?(user)).to be_truthy
        expect(bike.user_id).to be_blank
        expect(BikeDisplayer.display_edit_address_fields?(bike, user)).to be_falsey
        expect(BikeDisplayer.user_edit_bike_address?(bike, user)).to be_falsey
        expect(BikeDisplayer.display_edit_address_fields?(bike, admin)).to be_truthy
      end
    end
    context "bike.user" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: user) }
      before do
        expect(bike.authorized?(user)).to be_truthy
        expect(bike.user_id).to eq user.id
      end
      it "is truthy" do
        expect(BikeDisplayer.display_edit_address_fields?(bike, user)).to be_truthy
        expect(BikeDisplayer.user_edit_bike_address?(bike, user)).to be_truthy
        expect(BikeDisplayer.edit_street_address?(bike, user)).to be_falsey
        expect(BikeDisplayer.display_edit_address_fields?(bike, admin)).to be_truthy
      end
      context "user address set" do
        let(:user) { FactoryBot.create(:user, :in_amsterdam, address_set_manually: true) }
        it "is falsey" do
          expect(user.reload.address_set_manually).to be_truthy
          expect(BikeDisplayer.display_edit_address_fields?(bike, user)).to be_falsey
          expect(BikeDisplayer.user_edit_bike_address?(bike, user)).to be_falsey
          expect(BikeDisplayer.edit_street_address?(bike, user)).to be_falsey
          expect(BikeDisplayer.display_edit_address_fields?(bike, admin)).to be_falsey
          expect(BikeDisplayer.edit_street_address?(bike, admin)).to be_falsey
        end
      end
      context "user_registration_organization" do
        let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["reg_address"]) }
        let!(:user_registration_organization) { FactoryBot.create(:user_registration_organization, organization: organization, user: user) }
        it "is falsey" do
          expect(user.reload.address_set_manually).to be_falsey
          expect(user.user_registration_organizations.pluck(:id)).to eq([user_registration_organization.id])
          expect(user.uro_organizations.pluck(:id)).to eq([organization.id])
          expect(user.uro_organizations.first.additional_registration_fields).to eq(["reg_address"])
          expect(BikeDisplayer.user_edit_bike_address?(bike, user)).to be_falsey
          expect(BikeDisplayer.display_edit_address_fields?(bike, user)).to be_falsey
          expect(BikeDisplayer.edit_street_address?(bike, user)).to be_falsey
          expect(BikeDisplayer.display_edit_address_fields?(bike, admin)).to be_truthy
          expect(BikeDisplayer.edit_street_address?(bike, admin)).to be_falsey
        end
      end
      context "impounded" do
        let!(:impound_record) { FactoryBot.create(:impound_record, bike: bike) }
        it "is falsey" do
          expect(bike.reload.status).to eq "status_impounded"
          expect(BikeDisplayer.display_edit_address_fields?(bike, user)).to be_falsey
          expect(BikeDisplayer.user_edit_bike_address?(bike, user)).to be_truthy
          expect(BikeDisplayer.display_edit_address_fields?(bike, admin)).to be_falsey
        end
      end
      context "stolen" do
        let!(:impound_record) { FactoryBot.create(:impound_record, bike: bike) }
        it "is falsey" do
          expect(bike.reload.status).to eq "status_impounded"
          expect(BikeDisplayer.display_edit_address_fields?(bike, user)).to be_falsey
          expect(BikeDisplayer.user_edit_bike_address?(bike, user)).to be_truthy
          expect(BikeDisplayer.display_edit_address_fields?(bike, admin)).to be_falsey
        end
      end
      context "unregistered_parking_notification" do
        it "is falsey" do
          bike.status = "unregistered_parking_notification"
          expect(BikeDisplayer.display_edit_address_fields?(bike, user)).to be_falsey
          expect(BikeDisplayer.user_edit_bike_address?(bike, user)).to be_truthy
          expect(BikeDisplayer.display_edit_address_fields?(bike, admin)).to be_falsey
        end
      end
      context "bike street is present" do
        before { bike.update(street: "444 something") }
        it "is truthy" do
          expect(bike.reload.street).to eq "444 something"
          expect(BikeDisplayer.display_edit_address_fields?(bike, user)).to be_truthy
          expect(BikeDisplayer.user_edit_bike_address?(bike, user)).to be_truthy
          expect(BikeDisplayer.edit_street_address?(bike, user)).to be_truthy
          expect(BikeDisplayer.display_edit_address_fields?(bike, admin)).to be_truthy
          expect(BikeDisplayer.edit_street_address?(bike, admin)).to be_truthy
        end
      end
    end
    context "organized bike" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, user: user, creation_organization: organization) }
      let(:organization_member) { FactoryBot.create(:user, :with_organization, organization: organization) }
      it "is truthy" do
        expect(bike.authorized?(user)).to be_truthy
        expect(BikeDisplayer.display_edit_address_fields?(bike, user)).to be_truthy
        expect(BikeDisplayer.user_edit_bike_address?(bike, user)).to be_truthy
        expect(BikeDisplayer.edit_street_address?(bike, user)).to be_falsey
        expect(bike.authorized?(organization_member)).to be_truthy
        expect(BikeDisplayer.display_edit_address_fields?(bike, organization_member)).to be_truthy
        expect(BikeDisplayer.user_edit_bike_address?(bike, organization_member)).to be_truthy
        expect(BikeDisplayer.edit_street_address?(bike, organization_member)).to be_falsey
      end
      context "organization reg_address" do
        let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["reg_address"]) }
        it "is truthy" do
          expect(bike.authorized?(user)).to be_truthy
          expect(BikeDisplayer.display_edit_address_fields?(bike, user)).to be_truthy
          expect(BikeDisplayer.user_edit_bike_address?(bike, user)).to be_truthy
          expect(BikeDisplayer.edit_street_address?(bike, user)).to be_truthy
          expect(bike.authorized?(organization_member)).to be_truthy
          expect(BikeDisplayer.display_edit_address_fields?(bike, organization_member)).to be_truthy
          expect(BikeDisplayer.user_edit_bike_address?(bike, organization_member)).to be_truthy
          expect(BikeDisplayer.edit_street_address?(bike, organization_member)).to be_truthy
        end
      end
      context "user address set" do
        let(:user) { FactoryBot.create(:user, :in_amsterdam, address_set_manually: true) }
        it "is falsey" do
          expect(BikeDisplayer.display_edit_address_fields?(bike, user)).to be_falsey
          expect(BikeDisplayer.user_edit_bike_address?(bike, user)).to be_falsey
          expect(BikeDisplayer.edit_street_address?(bike, organization_member)).to be_falsey
          expect(BikeDisplayer.display_edit_address_fields?(bike, organization_member)).to be_falsey
          expect(BikeDisplayer.user_edit_bike_address?(bike, organization_member)).to be_falsey
          expect(BikeDisplayer.edit_street_address?(bike, organization_member)).to be_falsey
        end
      end
      context "no_address set" do
        let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["no_address"]) }
        it "is falsey" do
          expect(BikeDisplayer.display_edit_address_fields?(bike, user)).to be_truthy
          expect(BikeDisplayer.user_edit_bike_address?(bike, user)).to be_truthy
          expect(BikeDisplayer.display_edit_address_fields?(bike, organization_member)).to be_truthy
          expect(BikeDisplayer.user_edit_bike_address?(bike, organization_member)).to be_truthy
          expect(BikeDisplayer.edit_street_address?(bike, organization_member)).to be_falsey
          expect(BikeDisplayer.edit_street_address?(bike, admin)).to be_falsey
        end
      end
    end
  end
end
