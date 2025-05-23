require "rails_helper"

RSpec.describe BikeBookUpdateJob, type: :job do
  let(:subject) { BikeBookUpdateJob }

  it "is the correct queue" do
    expect(subject.sidekiq_options["queue"]).to eq "high_priority"
  end

  it "enqueues listing ordering job" do
    BikeBookUpdateJob.perform_async
    expect(BikeBookUpdateJob).to have_enqueued_sidekiq_job
  end

  it "Doesn't break if the bike isn't on bikebook" do
    bike = FactoryBot.create(:bike)
    BikeBookUpdateJob.new.perform(bike.id)
  end

  it "grabs the components but doesn't overwrite components if the bike isn't on bikebook", :flaky do
    manufacturer = FactoryBot.create(:manufacturer, name: "SE Bikes")
    bike = FactoryBot.create(:bike,
      manufacturer_id: manufacturer.id,
      year: 2014,
      frame_model: "Draft")
    ["fork",
      "crankset",
      "pedals",
      "chain",
      "wheel",
      "tire",
      "headset",
      "handlebar",
      "stem",
      "grips/tape",
      "saddle",
      "seatpost"].each { |name| FactoryBot.create(:ctype, name: name) }
    component1 = FactoryBot.create(:component,
      bike: bike, ctype_id: Ctype.friendly_find("fork").id,
      description: "SE straight Leg Hi-Ten w/ Fender Mounts & Wide Tire Clearance")
    expect(component1.is_stock).to be_falsey
    component2 = FactoryBot.create(:component,
      bike: bike, ctype_id: Ctype.friendly_find("crankset").id,
      description: "Sweet cranks")
    VCR.use_cassette("bike_book_update_worker", re_record_interval: 1.month) do
      BikeBookUpdateJob.new.perform(bike.id)
    end
    bike.reload
    expect(bike.components.count).to eq(14)
    expect(bike.components.where(id: component1.id).first.is_stock).to be_truthy
    expect(bike.components.where(id: component2.id).first.is_stock).to be_falsey
    expect(bike.components.where(is_stock: false).count).to eq(1)
    expect(bike.components.where(ctype_id: component2.ctype_id).count).to eq(1)
    expect(bike.components.pluck(:ctype_id).count).to eq 14
  end
end
