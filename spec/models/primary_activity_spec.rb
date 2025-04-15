require "rails_helper"

RSpec.describe PrimaryActivity, type: :model do
  it_behaves_like "short_nameable"

  describe "factory" do
    let(:primary_activity) { FactoryBot.create(:primary_activity) }
    it "is valid" do
      expect(primary_activity).to be_valid
      expect(primary_activity.flavor?).to be_truthy
    end

    context "primary_activity_flavor_with_family" do
      let(:primary_activity) { FactoryBot.create(:primary_activity_flavor_with_family) }
      it "is has family" do
        expect(primary_activity).to be_valid
        expect(primary_activity.flavor?).to be_truthy
        expect(primary_activity.primary_activity_family_id).to be_present
        expect(primary_activity.primary_activity_family.family?).to be_truthy
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
      expect(primary_activity.reload.priority).to eq 489
    end
  end
end
