require "spec_helper"

RSpec.describe BikeCode, type: :model do
  describe "normalize_code" do
    let(:url) { "https://bikeindex.org/bikes/scanned/000012?organization_id=palo-party" }
    let(:url2) { "bikeindex.org/bikes/000012/scanned?organization_id=bikeindex" }
    let(:url3) { "www.bikeindex.org/bikes/12/scanned?organization_id=bikeindex" }
    let(:url4) { "https://bikeindex.org/bikes/scanned/000012/" }
    let(:code) { "bike_code999" }
    it "strips the right stuff" do
      expect(BikeCode.normalize_code(code)).to eq "BIKE_CODE999"
      expect(BikeCode.normalize_code(url)).to eq "12"
      expect(BikeCode.normalize_code(url2)).to eq "12"
      expect(BikeCode.normalize_code(url3)).to eq "12"
      expect(BikeCode.normalize_code(url4)).to eq "12"
    end
  end

  describe "basic stuff" do
    let(:bike) { FactoryBot.create(:bike) }
    let(:organization) { FactoryBot.create(:organization, name: "Bike all night long", short_name: "bikenight") }
    let!(:spokecard) { FactoryBot.create(:bike_code, kind: "spokecard", code: 12, bike: bike) }
    let!(:sticker) { FactoryBot.create(:bike_code, code: 12, organization_id: organization.id) }
    let!(:sticker_dupe) { FactoryBot.build(:bike_code, code: "00012", organization_id: organization.id) }
    let!(:spokecard_text) { FactoryBot.create(:bike_code, kind: "spokecard", code: "a31b", bike: bike) }

    it "calls the things we expect and finds the things we expect" do
      expect(BikeCode.claimed.count).to eq 2
      expect(BikeCode.unclaimed.count).to eq 1
      expect(BikeCode.spokecard.count).to eq 2
      expect(BikeCode.sticker.count).to eq 1
      expect(BikeCode.lookup("000012", organization_id: organization.id)).to eq sticker
      expect(BikeCode.lookup("000012", organization_id: organization.to_param)).to eq sticker
      expect(BikeCode.lookup("https://bikeindex.org/bikes/scanned/000012?organization_id=#{organization.short_name}", organization_id: organization.short_name)).to eq sticker
      expect(BikeCode.lookup("000012", organization_id: organization.name)).to eq sticker
      expect(BikeCode.lookup("000012", organization_id: "whateves")).to eq spokecard
      expect(BikeCode.lookup("000012")).to eq spokecard
      expect(BikeCode.admin_text_search("1").pluck(:id)).to match_array([spokecard_text.id, spokecard.id, sticker.id])
      expect(BikeCode.admin_text_search(" ").pluck(:id)).to match_array([spokecard.id, sticker.id, spokecard_text.id])
      expect(BikeCode.admin_text_search("0012").pluck(:id)).to match_array([spokecard.id, sticker.id])
      expect(BikeCode.admin_text_search("a").pluck(:id)).to match_array([spokecard_text.id])
      expect(spokecard.claimed?).to be_truthy
      expect(sticker_dupe.save).to be_falsey
    end
  end

  describe "duplication and integers" do
    let(:organization) { FactoryBot.create(:organization) }
    let!(:sticker) { FactoryBot.create(:bike_code, kind: "sticker", code: 12, organization_id: organization.id) }
    let!(:sticker2) { FactoryBot.create(:bike_code, kind: "sticker", code: " 12", organization: FactoryBot.create(:organization)) }
    let!(:spokecard) { FactoryBot.create(:bike_code, kind: "spokecard", code: "00000012") }
    let!(:spokecard2) { FactoryBot.create(:bike_code, kind: "sticker", code: "a00000012") }
    let(:sticker_dupe_number) { FactoryBot.build(:bike_code, kind: "sticker", code: "00012", organization_id: organization.id) }
    # Note: unique across kinds, so just check that here
    let(:spokecard_dupe_letter) { FactoryBot.build(:bike_code, kind: "sticker", code: " A00000012") }
    let(:spokecard_empty) { FactoryBot.build(:bike_code, kind: "sticker", code: " ") }

    it "doesn't permit duplicates" do
      expect(sticker.code).to eq "12"
      expect(sticker2.code).to eq "12"
      expect(spokecard2.code).to eq "A00000012"
      [sticker, sticker2, spokecard, spokecard2].each { |bike_code| expect(bike_code).to be_valid }
      expect(sticker_dupe_number.save).to be_falsey
      expect(sticker_dupe_number.errors.messages.to_s).to match(/already been taken/i)
      expect(spokecard_dupe_letter.save).to be_falsey
      expect(sticker_dupe_number.errors.messages.to_s).to match(/already been taken/i)
      expect(spokecard_empty.save).to be_falsey
      expect(spokecard_empty.errors.messages.to_s).to match(/blank/i)
    end
  end

  describe "claimable_by?" do
    let(:user) { FactoryBot.create(:user) }
    let(:organization) { FactoryBot.create(:organization) }
    let(:membership) { FactoryBot.create(:membership, user: user, organization: organization) }
    before { stub_const("BikeCode::MAX_UNORGANIZED", 1) }
    it "is truthy" do
      expect(BikeCode.new.claimable_by?(user)).to be_truthy
      # Already claimed bikes can't be linked
      expect(BikeCode.new(bike_id: 1243).claimable_by?(user)).to be_falsey
    end
    context "user has too many bike_codes" do
      let!(:bike_code) { FactoryBot.create(:bike_code, user_id: user.id) }
      it "has expected values" do
        expect(BikeCode.new.claimable_by?(user)).to be_falsey
        expect(membership).to be_present
        user.reload
        expect(BikeCode.new.claimable_by?(user)).to be_falsey # Only has ability to link organized bike_codes
        expect(BikeCode.new(organization_id: organization.id).claimable_by?(user)).to be_truthy
        # Claimed can still be linked by a member of the org
        expect(BikeCode.new(organization_id: organization.id, bike_id: 1243).claimable_by?(user)).to be_truthy
        # Can't link other organization ones
        expect(BikeCode.new(organization_id: organization.id + 100).claimable_by?(user)).to be_falsey
        expect(BikeCode.new(bike_id: 1243).claimable_by?(user)).to be_falsey
      end
      context "user is superuser" do
        it "is always true" do
          user.superuser = true
          expect(BikeCode.new.claimable_by?(user)).to be_truthy
          expect(BikeCode.new(bike_id: 12).claimable_by?(user)).to be_truthy
        end
      end
    end
    context "user has too many organized bike_code" do
      let!(:bike_code) { FactoryBot.create(:bike_code, user_id: user.id, organization_id: organization.id) }
      it "has expected values" do
        expect(BikeCode.new.claimable_by?(user)).to be_falsey
        expect(membership).to be_present # Once user is part of the organization, they're permitted to link
        user.reload
        expect(BikeCode.new.claimable_by?(user)).to be_truthy
      end
    end
  end

  describe "next_unassigned" do
    let(:bike_code) { FactoryBot.create(:bike_code, organization_id: 12, code: "zzzz") }
    let(:bike_code1) { FactoryBot.create(:bike_code, organization_id: 12, code: "a1111") }
    let(:bike_code2) { FactoryBot.create(:bike_code, organization_id: 11, code: "a1112") }
    let(:bike_code3) { FactoryBot.create(:bike_code, organization_id: 12, code: "a1113", bike_id: 12) }
    let(:bike_code4) { FactoryBot.create(:bike_code, organization_id: 12, code: "a111") }
    it "finds next unassigned, returns nil if not found" do
      [bike_code, bike_code1, bike_code2, bike_code3, bike_code4]
      expect(bike_code1.next_unclaimed_code).to eq bike_code4
      expect(bike_code2.next_unclaimed_code).to be_nil
    end
    context "an unassigned lower code" do
      let!(:earlier_unclaimed) { FactoryBot.create(:bike_code, organization_id: 12, code: "a1110") }
      it "grabs the next one anyway" do
        [earlier_unclaimed, bike_code, bike_code1, bike_code2, bike_code3, bike_code4]
        expect(earlier_unclaimed.id).to be < bike_code4.id
        # expect(BikeCode.where(organization_id: 12).next_unclaimed_code).to eq bike_code4
        expect(BikeCode.where(organization_id: 11).next_unclaimed_code).to eq bike_code2
      end
    end
  end

  describe "claim" do
    let(:bike) { FactoryBot.create(:bike) }
    let(:user) { FactoryBot.create(:user) }
    let(:bike_code) { FactoryBot.create(:bike_code) }
    it "claims, doesn't update when unable to parse" do
      bike_code.claim(user, bike.id)
      expect(bike_code.user).to eq user
      expect(bike_code.bike).to eq bike
      bike_code.claim(user, "https://bikeindex.org/bikes/9#{bike.id}")
      expect(bike_code.errors.full_messages).to be_present
      expect(bike_code.bike).to eq bike
      bike_code.claim(user, "https://bikeindex.org/bikes?per_page=200")
      expect(bike_code.errors.full_messages).to be_present
      expect(bike_code.bike).to eq bike
      expect(bike_code.claimed_at).to be_within(1.second).of Time.now
    end
    context "with weird strings" do
      it "updates" do
        bike_code.claim(user, "\nwww.bikeindex.org/bikes/#{bike.id}/edit")
        expect(bike_code.errors.full_messages).to_not be_present
        expect(bike_code.bike).to eq bike
        bike_code.claim(user, "\nwww.bikeindex.org/bikes/#{bike.id} ")
        expect(bike_code.errors.full_messages).to_not be_present
        expect(bike_code.bike).to eq bike
      end
    end
    context "organized" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:user) { FactoryBot.create(:organization_member, organization: organization) }
      let(:bike_code) { FactoryBot.create(:bike_code, bike: bike, organization: organization) }
      it "permits unclaiming of organized bikes if already claimed" do
        bike_code.reload
        expect(bike_code.errors.full_messages).to_not be_present
        bike_code.claim(user, "\n ")
        expect(bike_code.errors.full_messages).to_not be_present
        expect(bike_code.bike_id).to be_nil
        expect(bike_code.claimed_at).to be_nil
        expect(bike_code.user_id).to be_nil
        # Since no bike is assigned, it isn't unclaimable again
        bike_code.claim(user, "\n ")
        expect(bike_code.errors.full_messages).to be_present
      end
      context "unclaiming with bikeindex.org url" do
        it "adds an error" do
          # Doesn't permit unclaiming by a bikeindex.org/ url, because that's probably a mistake
          bike_code.claim(user, "www.bikeindex.org/bikes/ ")
          expect(bike_code.errors.full_messages).to be_present
          expect(bike_code.bike).to eq bike
        end
      end

      context "unorganized" do
        let(:bike_code) { FactoryBot.create(:bike_code, bike: bike, organization: FactoryBot.create(:organization)) }
        it "can't unclaim other orgs bikes" do
          bike_code.claim(user, nil)
          expect(bike_code.errors.full_messages).to be_present
          expect(bike_code.claimed?).to be_truthy
          expect(bike_code.bike).to eq bike
        end
      end
    end
  end
end
