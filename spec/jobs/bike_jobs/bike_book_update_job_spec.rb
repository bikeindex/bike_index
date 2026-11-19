require "rails_helper"

RSpec.describe BikeJobs::BikeBookUpdateJob, type: :job do
  let(:subject) { BikeJobs::BikeBookUpdateJob }

  it "is the correct queue" do
    expect(subject.sidekiq_options["queue"]).to eq "high_priority"
  end

  it "enqueues listing ordering job" do
    BikeJobs::BikeBookUpdateJob.perform_async
    expect(BikeJobs::BikeBookUpdateJob).to have_enqueued_sidekiq_job
  end

  it "Doesn't break if the bike isn't on bikebook" do
    bike = FactoryBot.create(:bike)
    BikeJobs::BikeBookUpdateJob.new.perform(bike.id)
  end

  it "grabs the components but doesn't overwrite components if the bike isn't on bikebook" do
    sync_bikebook_models
    manufacturer = FactoryBot.create(:manufacturer, name: "Specialized")
    bike = FactoryBot.create(:bike, manufacturer:, year: 2025, frame_model: "Haul ST")
    %w[Fork Crankset Saddle].each { FactoryBot.create(:ctype, name: it) }
    component1 = FactoryBot.create(:component, bike:, ctype: Ctype.friendly_find("fork"), description: "2022 Globe Fork")
    expect(component1.is_stock).to be_falsey
    component2 = FactoryBot.create(:component, bike:, ctype: Ctype.friendly_find("crankset"), description: "Sweet cranks")

    BikeJobs::BikeBookUpdateJob.new.perform(bike.id)

    bike.reload
    expect(component1.reload.is_stock).to be_truthy
    expect(component2.reload.is_stock).to be_falsey
    expect(bike.components.where(is_stock: false).pluck(:id)).to eq([component2.id])
    expect(bike.components.where(ctype_id: component2.ctype_id).count).to eq(1)
    expect(bike.components.find_by(ctype: Ctype.friendly_find("saddle"))).to have_attributes(is_stock: true,
      description: "Specialized Body Geometry Comfort Gel", mnfg_name: "Specialized")
    expect(bike.components.count).to be > 3
  end
end
