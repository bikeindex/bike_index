require "rails_helper"

RSpec.describe Spreadsheets::Components do
  describe "to_csv" do
    let!(:cgroup) { FactoryBot.create(:cgroup, name: "Wheels") }
    let!(:ctype) { FactoryBot.create(:ctype, name: "Rim", secondary_name: nil, has_multiple: true, cgroup:) }
    let(:target) do
      ["name,secondary_name,has_multiple_locations,group",
        "Rim,,true,Wheels"]
    end
    it "generates" do
      expect(Ctype.count).to eq 1
      result = described_class.to_csv.split("\n")

      expect(result.first).to eq target.first
      expect(result.second).to eq target.second
      expect(result.length).to eq target.length
    end
  end

  describe "row" do
    let(:cgroup) { FactoryBot.create(:cgroup, name: "Frame and Fork") }
    let(:ctype) { FactoryBot.create(:ctype, name: "Stem", secondary_name: "Gooseneck", has_multiple: false, cgroup:) }
    let(:target) { ["Stem", "Gooseneck", false, "Frame and Fork"] }
    it "returns expected" do
      expect(described_class.send(:row_for, ctype)).to eq target
    end
  end

  describe "import methods" do
    let(:csv_path) { Rails.root.join("spec/fixtures/components-test-import.csv") }
    let!(:cgroup) { FactoryBot.create(:cgroup, name: "Frame and Fork") }

    def expect_target_ctypes
      stem = Ctype.friendly_find("Stem")
      expect(stem.secondary_name).to eq "Gooseneck"
      expect(stem.has_multiple).to be_falsey
      expect(stem.cgroup).to eq cgroup

      pannier = Ctype.friendly_find("Pannier")
      expect(pannier.has_multiple).to be_truthy
      expect(pannier.cgroup.name).to eq "Cargo"
    end

    describe "import" do
      it "imports, reusing the existing cgroup and creating a new one" do
        expect do
          expect { described_class.import(csv_path) }.to change(Ctype, :count).by 2
        end.to change(Cgroup, :count).by 1
        expect_target_ctypes
      end
    end

    describe "update_or_create_for!" do
      let(:row) { {name: "Stem", secondary_name: "Gooseneck", has_multiple_locations: "false", group: "Frame and Fork"} }
      context "with existing ctype" do
        let!(:ctype) { FactoryBot.create(:ctype, name: "Stem", cgroup: FactoryBot.create(:cgroup)) }
        it "updates without creating" do
          expect { described_class.send(:update_or_create_for!, row) }.to change(Ctype, :count).by 0
          ctype.reload
          expect(ctype.secondary_name).to eq "Gooseneck"
          expect(ctype.cgroup).to eq cgroup
        end
      end
      context "with no matching ctype" do
        it "creates" do
          expect { described_class.send(:update_or_create_for!, row) }.to change(Ctype, :count).by 1
          expect(Ctype.friendly_find("Stem").cgroup).to eq cgroup
        end
      end
    end
  end
end
