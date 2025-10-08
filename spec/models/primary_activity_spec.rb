require "rails_helper"

RSpec.describe PrimaryActivity, type: :model do
  it_behaves_like "short_nameable"

  describe "factory" do
    let(:primary_activity) { FactoryBot.create(:primary_activity) }
    it "is valid" do
      expect(primary_activity).to be_valid
      expect(primary_activity.flavor?).to be_truthy
      expect(primary_activity.primary_activity_family_id).to eq primary_activity.id
    end

    context "primary_activity_flavor_with_family" do
      let(:primary_activity) { FactoryBot.create(:primary_activity_flavor_with_family) }
      let(:primary_activity_family) { primary_activity.primary_activity_family }
      it "is has family" do
        expect(primary_activity).to be_valid
        expect(primary_activity.reload.flavor?).to be_truthy
        expect(primary_activity.primary_activity_family_id).to be_present
        expect(primary_activity_family.family?).to be_truthy
        expect(primary_activity_family.primary_activity_family_id).to eq primary_activity_family.id
      end
    end
  end

  describe "display_name" do
    let(:primary_activity) { FactoryBot.create(:primary_activity, name: "Bike Polo") }
    it "is the name" do
      expect(primary_activity.reload.name).to eq "Bike Polo"
      expect(primary_activity.reload.display_name).to eq "Bike Polo"
      expect(primary_activity.flavor?).to be_truthy
      expect(primary_activity.top_level?).to be_truthy
    end
    context "with family" do
      let(:atb_name) { "ATB (All Terrain Biking) — Gravel, Cyclocross, etc." }
      let(:primary_activity_family) { FactoryBot.create(:primary_activity_family, name: atb_name) }
      let(:primary_activity) { FactoryBot.create(:primary_activity, name:, primary_activity_family:) }
      let(:name) { "All Road" }
      it "is the name with the family" do
        expect(primary_activity.reload.primary_activity_family.short_name).to eq "ATB"
        expect(primary_activity.display_name).to eq "ATB: All Road"
        expect(primary_activity.display_name_search).to eq "ATB: ONLY All Road"
        expect(PrimaryActivity.friendly_find_id("ATB")).to eq primary_activity_family.id
        expect(PrimaryActivity.friendly_find_id("ALl Terrain Biking")).to eq primary_activity_family.id
      end
      context "with other primary_activity with same name" do
        let(:primary_activity_family_2) { FactoryBot.create(:primary_activity_family, name: "Road Biking") }
        let(:primary_activity_2) { FactoryBot.create(:primary_activity, name:, primary_activity_family: primary_activity_family_2) }
        it "is valid for both" do
          expect(primary_activity).to be_valid
          expect(primary_activity.display_name).to eq "ATB: All Road"

          expect(primary_activity_2).to be_valid
          expect(primary_activity_2.display_name).to eq "Road: All Road"
          expect(primary_activity_2.display_name_search).to eq "Road: ONLY All Road"
          expect(primary_activity_family_2.display_name_search).to eq "Road Biking"
          expect(PrimaryActivity.friendly_find_id("Road")).to eq primary_activity_family_2.id
          # but it doesn't allow there to be multiple family
          primary_activity_invalid = FactoryBot.build(:primary_activity_family, name: "Road Biking")
          expect(primary_activity_invalid).to_not be_valid
          expect(primary_activity_invalid.errors.full_messages.sort)
            .to eq(["Name has already been taken", "Slug has already been taken"])
        end
      end
      context "cyclocross" do
        let(:name) { "Cyclocross" }
        it "does not include family in name" do
          expect(primary_activity.reload.name).to eq "Cyclocross"
          expect(primary_activity.display_name).to eq "ATB: Cyclocross"
          expect(primary_activity.display_name_search).to eq "ATB: ONLY Cyclocross"
          expect(primary_activity_family.display_name_search).to eq atb_name
        end
      end
      context "Gravel" do
        let(:name) { "Gravel" }
        it "does not include family in name" do
          expect(primary_activity.reload.name).to eq "Gravel"
          expect(primary_activity.display_name).to eq "ATB: Gravel"
          expect(primary_activity.display_name_search).to eq "ATB: ONLY Gravel"
        end
      end

      context "track racing" do
        let(:primary_activity_family) { FactoryBot.create(:primary_activity_family, name: "Track racing") }
        let(:primary_activity) { FactoryBot.create(:primary_activity, name: "Pursuit", primary_activity_family:) }
        it "shortens to Track" do
          expect(primary_activity.reload.name).to eq "Pursuit"
          expect(primary_activity.display_name).to eq "Track: Pursuit"
          expect(primary_activity.display_name_search).to eq "Track: ONLY Pursuit"
          expect(PrimaryActivity.friendly_find_id("Track")).to eq primary_activity_family.id
          expect(primary_activity_family.display_name_search).to eq "Track racing"
        end
      end
    end
  end

  describe "priority" do
    let(:primary_activity_family) { FactoryBot.create(:primary_activity_family, name: "ATB (All Terrain Biking)") }
    let(:primary_activity) { FactoryBot.create(:primary_activity, name: "All Road", primary_activity_family:) }
    it "is expected" do
      expect(primary_activity_family.reload.priority).to eq 490
      expect(primary_activity.reload.priority).to eq 390
    end
  end

  describe "friendly_find_id_and_family_ids" do
    let(:primary_activity_family) { FactoryBot.create(:primary_activity_family, name: "ATB (All Terrain Biking)") }
    let!(:primary_activity) { FactoryBot.create(:primary_activity, primary_activity_family:) }
    let!(:primary_activity2) { FactoryBot.create(:primary_activity, primary_activity_family:) }
    let!(:primary_activity_other) { FactoryBot.create(:primary_activity, :with_family) }
    let!(:primary_activity_other_family) { primary_activity_other.primary_activity_family }
    let(:family_ids) { [primary_activity_family.id, primary_activity.id, primary_activity2.id].sort }
    let(:other_family_ids) { [primary_activity_other_family.id, primary_activity_other.id].sort }

    it "returns the primary_activity id" do
      expect(primary_activity.reload.primary_activity_family_id).to eq primary_activity_family.id
      expect(primary_activity_family.reload.primary_activity_family_id).to eq primary_activity_family.id
      expect(described_class.friendly_find_id(primary_activity.id)).to eq(primary_activity.id)
      expect(described_class.friendly_find_id(primary_activity_family.id)).to eq(primary_activity_family.id)

      expect(described_class.friendly_find_id_and_family_ids(primary_activity.id))
        .to eq([primary_activity.id, [primary_activity.id]])
      expect(described_class.friendly_find_id_and_family_ids(primary_activity.slug))
        .to eq([primary_activity.id, [primary_activity.id]])
      expect(described_class.friendly_find_id_and_family_ids(primary_activity.name))
        .to eq([primary_activity.id, [primary_activity.id]])

      expect(described_class.friendly_find_id_and_family_ids(primary_activity2.id))
        .to eq([primary_activity2.id, [primary_activity2.id]])

      expect(described_class.friendly_find_id_and_family_ids(primary_activity_family.id))
        .to eq([primary_activity_family.id, family_ids])
      expect(described_class.friendly_find_id_and_family_ids(primary_activity_family.slug))
        .to eq([primary_activity_family.id, family_ids])
      expect(described_class.friendly_find_id_and_family_ids("ATB"))
        .to eq([primary_activity_family.id, family_ids])

      expect(described_class.friendly_find_id_and_family_ids(primary_activity_other_family.id))
        .to eq([primary_activity_other_family.id, other_family_ids])
      expect(described_class.friendly_find_id_and_family_ids(primary_activity_other_family.slug))
        .to eq([primary_activity_other_family.id, other_family_ids])
      expect(described_class.friendly_find_id_and_family_ids(primary_activity_other_family.slug))
        .to eq([primary_activity_other_family.id, other_family_ids])

      expect(described_class.friendly_find_id_and_family_ids("dafdsfasdf")).to eq([])
    end
  end
end
