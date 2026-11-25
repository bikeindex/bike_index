require "rails_helper"

RSpec.describe Spreadsheets::WheelSizes do
  describe "to_csv" do
    let!(:wheel_size_2) { FactoryBot.create(:wheel_size, name: "21in moto", iso_bsd: 533, priority: :uncommon, description: "21in motorcycle rim (70/100-21, 80/100-21) Stark Varg front (Uncommon)") }
    let!(:wheel_size_1) { FactoryBot.create(:wheel_size, name: "7.7 x 2.8in", iso_bsd: 53, priority: :rare, description: "7.7 x 2.8in (196 x 71) PU wheel (Rare)") }
    let(:target) do
      ["name,iso_bsd,priority,description",
        "7.7 x 2.8in,53,rare,7.7 x 2.8in (196 x 71) PU wheel (Rare)",
        "21in moto,533,uncommon,\"21in motorcycle rim (70/100-21, 80/100-21) Stark Varg front (Uncommon)\""]
    end

    it "generates, ordered by iso_bsd, and re-imports without changes" do
      csv = described_class.to_csv
      expect(csv.split("\n")).to eq target

      expect { described_class.import(StringIO.new(csv)) }.not_to change { WheelSize.pluck(:iso_bsd, :name, :priority, :description, :updated_at) }
    end
  end

  describe "import" do
    let(:csv_content) do
      "name,iso_bsd,priority,description\n" \
        "14in,254,standard,14in (Standard size)\n" \
        "22in,457,uncommon,\"22in (22 x 1.75; x 2.125; x 3) Rad Power Radwagon cargo e-bikes (Uncommon)\"\n"
    end
    # fresh StringIO each call, since CSV.foreach consumes it
    def import_csv = described_class.import(StringIO.new(csv_content))
    let!(:wheel_size) { FactoryBot.create(:wheel_size, iso_bsd: 457, name: "22 x 1.75; x 2.125", priority: :rare) }

    it "creates new sizes, updates existing ones by iso_bsd, and is idempotent" do
      expect { import_csv }.to change(WheelSize, :count).by 1
      expect(WheelSize.find_by(iso_bsd: 254)).to have_attributes(name: "14in", priority: "standard", description: "14in (Standard size)")
      expect(wheel_size.reload).to have_attributes(name: "22in", priority: "uncommon", description: "22in (22 x 1.75; x 2.125; x 3) Rad Power Radwagon cargo e-bikes (Uncommon)")

      expect { import_csv }.not_to change(WheelSize, :count)
    end
  end
end
