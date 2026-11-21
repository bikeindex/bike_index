require "rails_helper"

RSpec.describe Backfills::PrimaryActivitySlugJob, type: :job do
  let(:primary_activity_family) { FactoryBot.create(:primary_activity_family, name: "MTB (Mountain Biking)") }
  let!(:primary_activity) { FactoryBot.create(:primary_activity, name: "Bikepacking", primary_activity_family:) }

  it "prefixes flavor slugs with their family" do
    primary_activity.update_column(:slug, "bikepacking")

    described_class.new.perform
    expect(primary_activity.reload.slug).to eq "mtb-bikepacking"
  end
end
