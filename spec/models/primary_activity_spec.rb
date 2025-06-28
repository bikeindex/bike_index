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
      expect(primary_activity.name).to eq "Bike Polo"
    end
    context "with family" do
      let(:primary_activity_family) { FactoryBot.create(:primary_activity_family, name: "ATB (All Terrain Bike)") }
      let(:primary_activity) { FactoryBot.create(:primary_activity, name:, primary_activity_family:) }
      let(:name) { "All Road" }
      it "is the name with the family" do
        expect(primary_activity.primary_activity_family.short_name).to eq "ATB"
        expect(primary_activity.display_name).to eq "ATB (All Terrain Bike): All Road"
      end
      context "with other primary_activity with same name" do
        let(:primary_activity_family_2) { FactoryBot.create(:primary_activity_family, name: "Road Bike") }
        let(:primary_activity_2) { FactoryBot.create(:primary_activity, name:, primary_activity_family: primary_activity_family_2) }
        it "is valid for both" do
          expect(primary_activity).to be_valid
          expect(primary_activity.display_name).to eq "ATB (All Terrain Bike): All Road"

          expect(primary_activity_2).to be_valid
          expect(primary_activity_2.display_name).to eq "Road Bike: All Road"
        end
      end
      context "gravel" do
        let(:name) { "Gravel" }
        it "does not include family in name" do
          expect(primary_activity.display_name).to eq "Gravel"
        end
      end
    end
  end

  describe "priority" do
    let(:primary_activity_family) { FactoryBot.create(:primary_activity_family, name: "ATB (All Terrain Bike)") }
    let(:primary_activity) { FactoryBot.create(:primary_activity, name: "All Road", primary_activity_family:) }
    it "is expected" do
      expect(primary_activity_family.reload.priority).to eq 490
      expect(primary_activity.reload.priority).to eq 390
    end
  end

  describe "friendly_find_id_and_family_ids" do
    let(:primary_activity_family) { FactoryBot.create(:primary_activity_family, name: "ATB (All Terrain Bike)") }
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
