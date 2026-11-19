require "rails_helper"

RSpec.describe Backfills::ManufacturerDigitSlugJob, type: :job do
  let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "101 Bikes") }
  let!(:manufacturer_secondary) { FactoryBot.create(:manufacturer, name: "No. 22 Bicycle Company (22 Bicycle Co.)") }
  let!(:manufacturer_unchanged) { FactoryBot.create(:manufacturer, name: "Cardinal Bikes") }

  it "re-slugs manufacturers whose slug or secondary slug is all digits" do
    manufacturer.update_column(:slug, "101")
    manufacturer_secondary.update_column(:secondary_slug, "22")
    manufacturer_unchanged.update_column(:slug, "cardinal_stale")

    described_class.new.perform
    expect(manufacturer.reload.slug).to eq "101_bikes"
    expect(manufacturer_secondary.reload.secondary_slug).to eq "22_bicycle"
    expect(manufacturer_unchanged.reload.slug).to eq "cardinal_stale"
  end

  context "manufacturer that can't be saved" do
    it "raises" do
      FactoryBot.create(:manufacturer).update_columns(name: "333", slug: "333")
      expect { described_class.new.perform }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
