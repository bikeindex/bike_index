require "rails_helper"

RSpec.describe Spreadsheets::PrimaryActivities do
  let!(:primary_activity) { FactoryBot.create(:primary_activity, name: "Bike Polo", priority: 1) }

  describe "to_csv" do
    let(:target) { ["flavor,families", "Bike Polo,"] }
    it "generates" do
      result = described_class.to_csv.split("\n")

      expect(result.first).to eq target.first
      expect(result.second).to eq target.second
      expect(result.length).to eq target.length
    end
    context "with family" do
      let(:primary_activity_family) { FactoryBot.create(:primary_activity_family, name: "ATB (All Terrain Bike)", priority: 10) }
      let!(:primary_activity_2) { FactoryBot.create(:primary_activity, name: "All Road", primary_activity_family:, priority: 4) }
      let(:target) { ["flavor,families", "All Road,ATB (All Terrain Bike)", "Bike Polo,"] }

      it "generates" do
        result = described_class.to_csv.split("\n")

        expect(result.first).to eq target.first
        expect(result.second).to eq target.second
        expect(result.third).to eq target.third
        expect(result.length).to eq target.length
      end

      context "with multiple families" do
        let(:primary_activity_family_2) { FactoryBot.create(:primary_activity_family, name: "Road Bike", priority: 9) }
        let!(:primary_activity_3) { FactoryBot.create(:primary_activity, name: "All Road", primary_activity_family: primary_activity_family_2, priority: 3) }
        let(:target) { ["flavor,families", "All Road,ATB (All Terrain Bike) & Road Bike", "Bike Polo,"] }

        it "generates" do
          expect(primary_activity_family.reload.priority).to be > primary_activity_family_2.reload.priority
          expect(primary_activity_2.reload.priority).to be > primary_activity_3.reload.priority

          result = described_class.to_csv.split("\n")

          expect(result.first).to eq target.first
          expect(result.second).to eq target.second
          expect(result.third).to eq target.third
          expect(result.length).to eq target.length
        end
      end
    end
  end

  describe "import methods" do
    let!(:primary_activity) { FactoryBot.create(:primary_activity_family, name: "Road Bike") }
    let(:csv_path) { Rails.root.join("spec/fixtures/primary_activities-test-import.csv") }
    let(:target_display_names) do
      ["Road Bike", "ATB (All Terrain Bike)", "ATB (All Terrain Bike): All Road", "Road Bike: All Road", "Bike Polo"]
    end

    describe "import" do
      it "imports" do
        expect do
          described_class.import(csv_path)
        end.to change(PrimaryActivity, :count).by 4

        expect(PrimaryActivity.all.map(&:display_name)).to match_array target_display_names
      end
    end
  end
end
