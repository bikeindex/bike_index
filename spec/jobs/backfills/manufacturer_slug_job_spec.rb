require "rails_helper"

RSpec.describe Backfills::ManufacturerSlugJob, type: :job do
  let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "Kona Bicycle Company (Kona Bikes)") }

  it "slugifies, keeping the old slug as the legacy slug" do
    manufacturer.update_columns(slug: "kona", legacy_slug: "kona")

    described_class.new.perform
    expect(manufacturer.reload.slug).to eq "kona-bicycle-company"
    expect(manufacturer.legacy_slug).to eq "kona"
    expect(manufacturer.secondary_slug).to eq "kona"
  end

  context "manufacturer that can't be saved" do
    it "raises" do
      FactoryBot.create(:manufacturer).update_columns(name: "333", slug: "333")
      expect { described_class.new.perform }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
