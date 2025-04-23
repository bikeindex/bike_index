require "rails_helper"

RSpec.describe Spreadsheets::Manufacturers do
  let!(:manufacturer) do
    Manufacturer.destroy_all
    FactoryBot.create(:manufacturer, name: "Riese & Müller (Riese and Muller)", frame_maker: true,
      motorized_only: true, open_year: 1993, website: "https://www.r-m.de/")
  end
  describe "to_csv" do
    let(:target) do
      ["name,alternate_name,website,makes_frames,ebike_only,open_year,close_year,logo_url",
        "Riese & Müller,Riese and Muller,https://www.r-m.de/,true,true,1993,,"]
    end
    it "generates" do
      expect(Manufacturer.other).to be_present
      expect(Manufacturer.count).to eq 2
      result = described_class.to_csv.split("\n")

      expect(result.first).to eq target.first
      expect(result.second).to eq target.second
      expect(result.length).to eq target.length # it doesn't include other
    end
  end

  describe "row" do
    let(:target) do
      ["Riese & Müller", "Riese and Muller", "https://www.r-m.de/", true, true, 1993, nil, nil]
    end
    it "returns expected" do
      expect(described_class.send(:row_for, manufacturer)).to eq target
    end
  end

  describe "import methods" do
    let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "Btwin") }
    let(:csv_path) { Rails.root.join("spec/fixtures/manufacturer-test-import.csv") }

    def expect_target_manufacturer(mnfg)
      expect(mnfg.name).to eq("b'Twin (Btwin)")
      expect(mnfg.frame_maker).to be_truthy
      expect(mnfg.motorized_only).to be_falsey
      expect(mnfg.open_year).to eq 1976
      expect(mnfg.close_year).to be_blank
    end

    describe "import" do
      it "imports" do
        expect do
          described_class.import(csv_path)
        end.to change(Manufacturer, :count).by 1
        expect_target_manufacturer(manufacturer.reload)
      end
    end

    describe "update_or_create_for!" do
      let(:row) do
        {
          name: "b'Twin",
          alternate_name: "Btwin",
          website: "https://www.decathlon.com/g",
          makes_frames: "true",
          ebike_only: nil,
          open_year: "1976",
          close_year: nil,
          logo_url: "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e5/Decathlon_Logo24.svg/1600px-Decathlon_Logo24.svg.png"
        }
      end

      it "updates" do
        expect { described_class.send(:update_or_create_for!, row) }.to change(Manufacturer, :count).by 0
        expect_target_manufacturer(manufacturer.reload)
      end
      context "with existing mnfg with alternate_name" do
        let(:manufacturer) { FactoryBot.create(:manufacturer, name: "B'twin something (Btwin)") }
        it "updates" do
          expect { described_class.send(:update_or_create_for!, row) }.to change(Manufacturer, :count).by 0
          expect_target_manufacturer(manufacturer.reload)
        end
      end
      context "with no matching manufacturer" do
        let!(:manufacturer) { nil }
        it "creates" do

          expect { described_class.send(:update_or_create_for!, row) }.to change(Manufacturer, :count).by 1
          expect_target_manufacturer(Manufacturer.order(:id).last)
        end
      end
    end
  end
end
