require "rails_helper"
require "tempfile"

RSpec.describe Spreadsheets::PrimaryActivities do
  let!(:primary_activity) { FactoryBot.create(:primary_activity, name: "Bike Polo", priority: 1) }

  describe "to_csv" do
    let(:target) { ["flavor,families,priority,short_name,slug", "Bike Polo,,1,Bike Polo,bike-polo"] }
    it "generates" do
      result = described_class.to_csv.split("\n")

      expect(result.first).to eq target.first
      expect(result.second).to eq target.second
      expect(result.length).to eq target.length
    end
    context "with family" do
      let(:primary_activity_family) { FactoryBot.create(:primary_activity_family, name: "ATB (All Terrain Biking)", priority: 10) }
      let!(:primary_activity_2) { FactoryBot.create(:primary_activity, name: "All Road", primary_activity_family:, priority: 4) }
      # The family exports as a flavor-less row (empty flavor column)
      let(:target) { ["flavor,families,priority,short_name,slug", ",ATB (All Terrain Biking),10,ATB,atb", "All Road,ATB (All Terrain Biking),4,All Road,atb-all-road", "Bike Polo,,1,Bike Polo,bike-polo"] }

      it "generates" do
        result = described_class.to_csv.split("\n")

        expect(result.first).to eq target.first
        expect(result.second).to eq target.second
        expect(result.third).to eq target.third
        expect(result.fourth).to eq target.fourth
        expect(result.length).to eq target.length
      end

      context "with multiple families" do
        let(:primary_activity_family_2) { FactoryBot.create(:primary_activity_family, name: "Road Biking", priority: 9) }
        let!(:primary_activity_3) { FactoryBot.create(:primary_activity, name: "All Road", primary_activity_family: primary_activity_family_2, priority: 3) }
        let(:target) do
          ["flavor,families,priority,short_name,slug",
            ",ATB (All Terrain Biking),10,ATB,atb",
            ",Road Biking,9,Road,road-biking",
            "All Road,ATB (All Terrain Biking),4,All Road,atb-all-road",
            "All Road,Road Biking,3,All Road,road-all-road",
            "Bike Polo,,1,Bike Polo,bike-polo"]
        end

        it "generates" do
          expect(primary_activity_family.reload.priority).to be > primary_activity_family_2.reload.priority
          expect(primary_activity_2.reload.priority).to be > primary_activity_3.reload.priority

          result = described_class.to_csv.split("\n")

          expect(result).to eq target
        end
      end
    end
  end

  describe "round-trips its own export" do
    # A top-level "Bike Polo" flavor comes from the enclosing let!
    let!(:family) { FactoryBot.create(:primary_activity_family, name: "Road Biking") }
    let!(:flavor) { FactoryBot.create(:primary_activity, name: "Triathalon", primary_activity_family: family) }
    let!(:family_2) { FactoryBot.create(:primary_activity_family, name: "Track Racing") }
    let!(:time_trial) { FactoryBot.create(:primary_activity, name: "Time Trial", primary_activity_family: family, priority: 237) }
    let!(:time_trial_2) { FactoryBot.create(:primary_activity, name: "Time Trial", primary_activity_family: family_2, priority: 77) }

    it "re-imports the exported CSV without creating a flavor for a family row" do
      Tempfile.create(["primary_activities", ".csv"], Rails.root.join("tmp")) do |file|
        file.write(described_class.to_csv)
        file.flush

        expect { described_class.import(file.path) }.not_to change(PrimaryActivity, :count)
      end

      expect(PrimaryActivity.all.map(&:display_name)).to match_array ["Road Biking", "Road: Triathalon", "Road: Time Trial", "Track Racing", "Track: Time Trial", "Bike Polo"]
    end

    it "restores priorities" do
      csv = described_class.to_csv
      PrimaryActivity.update_all(priority: 0)

      described_class.import(StringIO.new(csv))

      expect(described_class.to_csv).to eq csv
      expect([time_trial.reload.priority, time_trial_2.reload.priority]).to eq [237, 77]
    end
  end

  describe "import methods" do
    let!(:primary_activity) { FactoryBot.create(:primary_activity_family, name: "Road Biking") }
    let(:csv_path) { Rails.root.join("spec/fixtures/primary_activities-test-import.csv") }
    let(:target_display_names) do
      ["Road Biking", "ATB (All Terrain Biking)", "ATB: All Road", "Road: All Road", "Bike Polo"]
    end

    describe "import" do
      it "imports" do
        expect do
          described_class.import(csv_path)
        end.to change(PrimaryActivity, :count).by 4

        expect(PrimaryActivity.all.map(&:display_name)).to match_array target_display_names
      end

      it "is idempotent on re-import (top-level flavors included)" do
        described_class.import(csv_path)

        expect { described_class.import(csv_path) }.not_to change(PrimaryActivity, :count)
        expect(PrimaryActivity.all.map(&:display_name)).to match_array target_display_names
      end

      it "self-heals slug drift on re-import (no collision)" do
        described_class.import(csv_path)
        # Drift the slug so the slug lookup misses; the exact-name fallback should still find it
        PrimaryActivity.flavor.top_level.friendly_find("Bike Polo").update_columns(slug: "drifted")

        expect { described_class.import(csv_path) }.not_to change(PrimaryActivity, :count)
      end

      it "names the offending activity when a create fails validation" do
        # A top-level flavor sharing a name with an existing family is a genuine conflict
        Tempfile.create(["primary_activities", ".csv"], Rails.root.join("tmp")) do |file|
          file.write("Flavor,Families\nRoad Biking,\n")
          file.flush
          expect { described_class.import(file.path) }.to raise_error(/Road Biking/)
        end
      end

      it "sets each row's priority on its own activity, not on the families it lists" do
        described_class.import(StringIO.new("flavor,families,priority\n,Road Biking,590\nAll Road,ATB (All Terrain Biking) & Road Biking,268\nBike Polo,,401\n"))

        expect(primary_activity.reload.priority).to eq 590
        all_road = PrimaryActivity.flavor.where(name: "All Road")
        expect(all_road.pluck(:priority)).to eq [268, 268]
        atb = PrimaryActivity.family.find_by(name: "ATB (All Terrain Biking)")
        expect(atb.priority).to_not eq 268
        expect(PrimaryActivity.flavor.top_level.friendly_find("Bike Polo").priority).to eq 401
      end

      it "corrects the stored name of an existing activity (e.g. casing)" do
        described_class.import(csv_path)
        bike_polo = PrimaryActivity.flavor.top_level.friendly_find("Bike Polo")
        bike_polo.update_columns(name: "Bike polo") # bypass callbacks; slug stays "bike-polo"

        expect { described_class.import(csv_path) }.not_to change(PrimaryActivity, :count)
        expect(bike_polo.reload.name).to eq "Bike Polo"
      end

      it "matches on exact slug, not a substring, so it never renames a different activity" do
        described_class.import(csv_path)
        bike_polo = PrimaryActivity.flavor.top_level.friendly_find("Bike Polo")

        # "Polo" is an ILIKE substring of "Bike Polo" but a distinct activity
        Tempfile.create(["primary_activities", ".csv"], Rails.root.join("tmp")) do |file|
          file.write("Flavor,Families\nPolo,\n")
          file.flush
          expect { described_class.import(file.path) }.to change(PrimaryActivity, :count).by(1)
        end

        expect(bike_polo.reload.name).to eq "Bike Polo"
        expect(PrimaryActivity.flavor.top_level.find_by(slug: "polo")).to be_present
      end
    end
  end
end
