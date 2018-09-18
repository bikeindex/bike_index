require "spec_helper"

RSpec.describe Export, type: :model do
  describe "scope and method for stolen_no_blacklist" do
    let(:export) { FactoryGirl.create(:export, options: { with_blacklist: true }) }
    it "is with blacklist" do
      expect(export.stolen?).to be_truthy
      expect(export.options).to eq(Export.default_options["stolen"].merge("with_blacklist" => true))
      expect(export.has_option?(:with_blacklist)).to be_truthy
      expect(export.has_option?(:only_serials_and_police_reports)).to be_falsey
      expect(export.description).to eq "Stolen"
      expect(Export.stolen).to eq([export])
    end
  end
  describe "organization" do
    let(:export) { FactoryGirl.create(:export_organization) }
    it "is as expected" do
      expect(export.stolen?).to be_falsey
      expect(export.organization?).to be_truthy
      expect(export.has_option?("start_at")).to be_falsey
      expect(Export.organization).to eq([export])
    end
  end
end
