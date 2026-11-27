require "rails_helper"

RSpec.describe Backfills::ManufacturerSlugJob, type: :job do
  let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "Kona Bicycle Company (Kona Bikes)") }

  it "slugifies, keeping the old slug as a previous slug and dashing underscored ones" do
    manufacturer.update_columns(slug: "kona_old", secondary_slug: "kona_bikes", previous_slugs: %w[kona_bicycle_co])

    described_class.new.perform
    expect(manufacturer.reload.slug).to eq "kona-bicycle-company"
    expect(manufacturer.secondary_slug).to eq "kona"
    expect(manufacturer.previous_slugs).to eq %w[kona-bicycle-co kona-old kona]
    expect(Manufacturer.friendly_find("kona_old")&.id).to eq manufacturer.id
    expect(Manufacturer.friendly_find("Kona Bicycle Co")&.id).to eq manufacturer.id
  end

  context "manufacturer that can't be saved" do
    it "raises" do
      FactoryBot.create(:manufacturer).update_columns(name: "333", slug: "333")
      expect { described_class.new.perform }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
