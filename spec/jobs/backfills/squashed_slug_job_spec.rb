require "rails_helper"

RSpec.describe Backfills::SquashedSlugJob, type: :job do
  let!(:organization_dashes) { FactoryBot.create(:organization, name: "Abq - UNM") }
  let!(:organization_amp) { FactoryBot.create(:organization, name: "J&J Cycle") }
  let!(:organization_other) { FactoryBot.create(:organization, name: "Some Shop") }
  let!(:primary_activity) { FactoryBot.create(:primary_activity, name: "Keirin / NJS") }

  it "updates the slugs friendly_find can't reach, keeping the old one as previous_slug" do
    organization_dashes.update_columns(slug: "abq---unm")
    organization_amp.update_columns(slug: "jj-cycle")
    organization_other.update_columns(slug: "some-shop-2")
    primary_activity.update_columns(slug: "keirin--njs")

    described_class.new.perform
    expect(organization_dashes.reload.slug).to eq "abq-unm"
    expect(Organization.friendly_find("abq---unm")&.id).to eq organization_dashes.id
    expect(organization_amp.reload.slug).to eq "j-amp-j-cycle"
    expect(organization_amp.previous_slug).to eq "jj-cycle"
    expect(Organization.friendly_find("jj-cycle")&.id).to eq organization_amp.id
    expect(organization_other.reload.slug).to eq "some-shop-2"
    expect(primary_activity.reload.slug).to eq "keirin-njs"
    expect(PrimaryActivity.friendly_find("Keirin / NJS")&.id).to eq primary_activity.id
  end
end
