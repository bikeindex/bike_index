require "rails_helper"

RSpec.describe Spreadsheets::Manufacturer do
  let!(:manufacturer) do
    FactoryBot.create(:manufacturer, name: "Riese & Müller (Riese and Muller)", frame_maker: true,
      motorized_only: true, open_year: 1993, website: "https://www.r-m.de/")
  end
  describe "to_csv" do
    let(:target) do
      ['name,alternate_name,website,makes_frames,ebike_only,open_year,close_year,logo_url',
       'Riese & Müller,Riese and Muller,https://www.r-m.de/,true,true,1993,,']
    end
    it "generates" do
      result = described_class.to_csv.split("\n")

      expect(result.first).to eq target.first
      expect(result.second).to eq target.second
      expect(result.length).to eq target.length
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

  # describe "import csv" do
  #   it "adds manufacturers to the list" do
  #     import_file = File.open(Rails.root.to_s + "/spec/fixtures/manufacturer-test-import.csv")
  #     expect {
  #       Manufacturer.import(import_file)
  #     }.to change(Manufacturer, :count).by(2)
  #   end

  #   it "adds in all the attributes that are listed" do
  #     import_file = File.open(Rails.root.to_s + "/spec/fixtures/manufacturer-test-import.csv")
  #     Manufacturer.import(import_file)
  #     manufacturer = Manufacturer.find_by_slug("surly")
  #     expect(manufacturer.website).to eq("http://surlybikes.com")
  #     expect(manufacturer.frame_maker).to be_truthy
  #     expect(manufacturer.open_year).to eq(1900)
  #     expect(manufacturer.close_year).to eq(3000)
  #     manufacturer2 = Manufacturer.find_by_slug("wethepeople")
  #     expect(manufacturer2.website).to eq("http://wethepeople.com")
  #   end

  #   it "updates attributes on a second upload" do
  #     import_file = File.open(Rails.root.to_s + "/spec/fixtures/manufacturer-test-import.csv")
  #     Manufacturer.import(import_file)
  #     second_import_file = File.open(Rails.root.to_s + "/spec/fixtures/manufacturer-test-import-second.csv")
  #     Manufacturer.import(second_import_file)
  #     expect(Manufacturer.find_by_slug("surly")).to be_present
  #   end
  # end
end
