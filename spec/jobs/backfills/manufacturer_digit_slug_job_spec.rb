require "rails_helper"

RSpec.describe Backfills::ManufacturerDigitSlugJob, type: :job do
  let(:manufacturer) { FactoryBot.create(:manufacturer, name: "101 Bikes") }
  let(:manufacturer_unchanged) { FactoryBot.create(:manufacturer, name: "Cardinal Bikes") }

  it "re-slugs manufacturers whose slug is all digits" do
    # The slug the old Slugifyer gave it
    manufacturer.update_column(:slug, "101")

    described_class.new.perform
    expect(manufacturer.reload.slug).to eq "101_bikes"
    expect(manufacturer_unchanged.reload.slug).to eq "cardinal"
  end
end
