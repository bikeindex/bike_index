require "rails_helper"

RSpec.describe Backfills::SquashedSlugJob, type: :job do
  let!(:organization_dashes) { FactoryBot.create(:organization, name: "Abq - UNM") }
  let!(:organization_plus) { FactoryBot.create(:organization, name: "Heron Flats + Lofts") }
  let!(:organization_amp) { FactoryBot.create(:organization, name: "J&J Cycle") }
  let!(:organization_other) { FactoryBot.create(:organization, name: "Some Shop") }
  let!(:organization_unchanged) { FactoryBot.create(:organization, name: "Other Shop", previous_slug: "old-shop") }
  let!(:organization_hub) { FactoryBot.create(:organization, name: "Bike Hub") }
  let!(:organization_hub_suffixed) { FactoryBot.create(:organization, name: "Bike Hub!", previous_slug: "old-hub") }
  let!(:primary_activity) { FactoryBot.create(:primary_activity, name: "Keirin / NJS") }
  let!(:ctype) { FactoryBot.create(:ctype, name: "Wheel / Tire") }
  let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "Busch + Muller") }
  let!(:manufacturer_amp) { FactoryBot.create(:manufacturer, name: "Laurin & Klement") }

  it "updates the slugs friendly_find can't reach, keeping the old one as previous_slug" do
    organization_dashes.update_columns(slug: "abq---unm")
    organization_plus.update_columns(slug: "heron-flats--lofts")
    organization_amp.update_columns(slug: "jj-cycle")
    organization_other.update_columns(slug: "some-shop-2")
    primary_activity.update_columns(slug: "keirin--njs")
    ctype.update_columns(slug: "wheel--tire")
    manufacturer.update_columns(slug: "busch--muller")
    manufacturer_amp.update_columns(slug: "laurin-amp-klement")

    described_class.new.perform
    expect(organization_dashes.reload.slug).to eq "abq-unm"
    expect(Organization.friendly_find("abq---unm")&.id).to eq organization_dashes.id
    expect(organization_plus.reload.slug).to eq "heron-flats-plus-lofts"
    expect(Organization.friendly_find("heron-flats--lofts")&.id).to eq organization_plus.id
    expect(organization_amp.reload.slug).to eq "j-and-j-cycle"
    expect(organization_amp.previous_slug).to eq "jj-cycle"
    expect(Organization.friendly_find("jj-cycle")&.id).to eq organization_amp.id
    expect(organization_other.reload.slug).to eq "some-shop"
    expect(Organization.friendly_find("some-shop-2")&.id).to eq organization_other.id
    expect(organization_unchanged.reload.previous_slug).to eq "old-shop"
    expect(primary_activity.reload.slug).to eq "keirin-njs"
    expect(PrimaryActivity.friendly_find("Keirin / NJS")&.id).to eq primary_activity.id
    expect(Ctype.friendly_find("wheel--tire")&.id).to eq ctype.id
    expect(manufacturer.reload.slug).to eq "busch-plus-muller"
    expect(Manufacturer.friendly_find("busch--muller")&.id).to eq manufacturer.id
    expect(manufacturer_amp.reload.slug).to eq "laurin-and-klement"
    expect(Manufacturer.friendly_find("laurin-amp-klement")&.id).to eq manufacturer_amp.id
    expect(organization_hub_suffixed.reload.slug).to eq "bike-hub-2"
    expect(organization_hub_suffixed.previous_slug).to eq "old-hub"
  end

  it "skips an organization with a previous_slug, then raises naming it" do
    organization_existing = FactoryBot.create(:organization, name: "Bike East Bay", previous_slug: "ebbc")
    organization_existing.update_columns(slug: "bike--east-bay")
    organization_amp.update_columns(slug: "jj-cycle")
    expect { described_class.new.perform }.to raise_error(/previous_slug: #{organization_existing.id}\z/)
    expect(organization_existing.reload.slug).to eq "bike--east-bay"
    expect(organization_existing.previous_slug).to eq "ebbc"
    expect(organization_amp.reload.slug).to eq "j-and-j-cycle"
    expect(organization_amp.previous_slug).to eq "jj-cycle"
  end

  it "is safe to run twice" do
    organization_amp.update_columns(slug: "jj-cycle")
    2.times { described_class.new.perform }
    expect(organization_amp.reload.previous_slug).to eq "jj-cycle"
    expect(Organization.friendly_find("jj-cycle")&.id).to eq organization_amp.id
  end
end
