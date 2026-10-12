require "rails_helper"

RSpec.describe Spreadsheets::WheelSizes do
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
