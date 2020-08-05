require "rails_helper"

RSpec.describe BikeStickerUpdateMigrationWorker, type: :job do
  let(:instance) { described_class.new }

  context "unclaimed sticker" do
    let(:updated_at) { Time.current - 2.hours }
    let(:bike_sticker) { FactoryBot.create(:bike_sticker, updated_at: Time.current - 2.hours) }
    it "does not update a sticker that is unclaimed" do
      bike_sticker.reload
      expect(bike_sticker.updated_at).to be_within(1).of updated_at
      expect { instance.perform(bike_sticker.id) }.to_not change(BikeStickerUpdate, :count)
      bike_sticker.reload
      expect(bike_sticker.updated_at).to be_within(1).of updated_at
    end
  end

  context "claimed by user" do
    let(:claimed_at) { Time.current - 2.weeks }
    let(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, claimed_at: claimed_at) }
    let(:user) { bike_sticker.user }
    let(:bike) { bike_sticker.bike }

    it "creates updates" do
      bike_sticker.reload
      expect(bike_sticker.organization).to be_blank
      expect { instance.perform(bike_sticker.id) }.to change(BikeStickerUpdate, :count).by 1
      bike_sticker.reload
      expect(bike_sticker.organization).to be_blank
      expect(bike_sticker.bike_sticker_updates.count).to eq 1
      bike_sticker_update = bike_sticker.bike_sticker_updates.last
      expect(bike_sticker_update.created_at).to be_within(1).of claimed_at
      expect(bike_sticker_update.user).to eq user
      expect(bike_sticker_update.bike).to eq bike
      expect(bike_sticker_update.organization).to be_blank
      expect(bike_sticker_update.kind).to eq "initial_claim"
      expect(bike_sticker_update.creator_kind).to eq "creator_user"
      expect(bike_sticker_update.organization_kind).to eq "no_organization"
    end
    context "previous_bike_id" do
      let(:bike1) { FactoryBot.create(:bike) }
      let(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, claimed_at: claimed_at, previous_bike_id: bike1.id) }
      it "creates a second bike_sticker_update" do
        expect { instance.perform(bike_sticker.id) }.to change(BikeStickerUpdate, :count).by 2
        bike_sticker.reload
        expect(bike_sticker.organization).to be_blank
        expect(bike_sticker.bike_sticker_updates.count).to eq 2
        bike_sticker_update1 = bike_sticker.bike_sticker_updates.reorder(:created_at).first
        expect(bike_sticker_update1.created_at).to be_within(5).of claimed_at - 1.hour
        expect(bike_sticker_update1.user).to be_blank
        expect(bike_sticker_update1.bike).to eq bike1
        expect(bike_sticker_update1.organization).to be_blank
        expect(bike_sticker_update1.kind).to eq "initial_claim"
        expect(bike_sticker_update1.creator_kind).to eq "creator_user"
        expect(bike_sticker_update1.organization_kind).to eq "no_organization"
        expect(bike_sticker_update1.update_number).to eq 1

        bike_sticker_update2 = bike_sticker.bike_sticker_updates.reorder(:created_at).last
        expect(bike_sticker_update2.created_at).to be_within(1).of claimed_at
        expect(bike_sticker_update2.user).to eq user
        expect(bike_sticker_update2.bike).to eq bike
        expect(bike_sticker_update2.organization).to be_blank
        expect(bike_sticker_update2.kind).to eq "re_claim"
        expect(bike_sticker_update2.creator_kind).to eq "creator_user"
        expect(bike_sticker_update2.organization_kind).to eq "no_organization"
        expect(bike_sticker_update2.update_number).to eq 2
      end
    end
  end

  context "claimed by organization" do
    let(:claimed_at) { Time.current - 1.year }
    let(:organization1) { FactoryBot.create(:organization) }
    let(:organization2) { FactoryBot.create(:organization) }
    let(:user) { FactoryBot.create(:organization_member, organization: organization2) }
    let!(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, claimed_at: claimed_at, organization: organization1, user: user) }
    let(:bike) { bike_sticker.bike }
    it "creates update, adds secondary organization to sticker" do
      organization1.reload
      organization2.reload
      expect(organization1.bike_stickers.pluck(:id)).to eq([bike_sticker.id])
      expect(organization2.bike_stickers.pluck(:id)).to eq([])
      bike_sticker.reload
      expect(bike_sticker.organization).to eq organization1
      expect(bike_sticker.secondary_organization).to be_blank
      expect(organization1.id).to_not eq user.organizations.first.id
      expect { instance.perform(bike_sticker.id) }.to change(BikeStickerUpdate, :count).by 1
      bike_sticker.reload
      expect(bike_sticker.organization).to eq organization1
      expect(bike_sticker.secondary_organization).to eq organization2
      expect(bike_sticker.bike_sticker_updates.count).to eq 1
      bike_sticker_update = bike_sticker.bike_sticker_updates.last
      expect(bike_sticker_update.created_at).to be_within(1).of claimed_at
      expect(bike_sticker_update.user).to eq user
      expect(bike_sticker_update.bike).to eq bike
      expect(bike_sticker_update.organization).to eq organization2
      expect(bike_sticker_update.kind).to eq "initial_claim"
      expect(bike_sticker_update.creator_kind).to eq "creator_user"
      expect(bike_sticker_update.organization_kind).to eq "other_organization"
      expect(organization1.bike_stickers.pluck(:id)).to eq([bike_sticker.id])
      expect(organization2.bike_stickers.pluck(:id)).to eq([bike_sticker.id])
    end
    context "regional organization" do
      let(:organization3) { FactoryBot.create(:organization, :in_edmonton) }
      let(:organization1) { FactoryBot.create(:organization_with_regional_bike_counts, :in_edmonton, regional_ids: [organization3.id]) }
      let!(:membership2) { FactoryBot.create(:membership_claimed, organization: organization3, user: user) }
      it "creates update, correctly chooses secondary organization" do
        organization1.reload
        organization3.reload
        expect(organization1.bike_stickers.pluck(:id)).to eq([bike_sticker.id])
        expect(organization3.bike_stickers.pluck(:id)).to eq([])
        expect(organization1.regional?).to be_truthy
        expect(organization1.regional_ids).to eq([organization3.id])
        organization3.reload
        expect(organization3.regional_parents.pluck(:id)).to eq([organization1.id])

        bike_sticker.reload
        expect(bike_sticker.organization).to eq organization1
        expect(bike_sticker.secondary_organization).to be_blank
        expect(user.organizations.pluck(:id)).to match_array([organization2.id, organization3.id])
        expect { instance.perform(bike_sticker.id) }.to change(BikeStickerUpdate, :count).by 1
        bike_sticker.reload
        expect(bike_sticker.organization).to eq organization1
        expect(bike_sticker.secondary_organization).to eq organization3
        expect(bike_sticker.bike_sticker_updates.count).to eq 1
        bike_sticker_update = bike_sticker.bike_sticker_updates.last
        expect(bike_sticker_update.created_at).to be_within(1).of claimed_at
        expect(bike_sticker_update.user).to eq user
        expect(bike_sticker_update.bike).to eq bike
        expect(bike_sticker_update.organization).to eq organization3
        expect(bike_sticker_update.kind).to eq "initial_claim"
        expect(bike_sticker_update.creator_kind).to eq "creator_user"
        expect(bike_sticker_update.organization_kind).to eq "regional_organization"
        expect(organization1.bike_stickers.pluck(:id)).to eq([bike_sticker.id])
        expect(organization3.bike_stickers.pluck(:id)).to eq([bike_sticker.id])
      end
    end
  end
end
