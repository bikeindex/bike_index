require 'spec_helper'

describe BikeBookUpdateWorker do
  it { should be_processed_in :updates }

  it "enqueues listing ordering job" do
    BikeBookUpdateWorker.perform_async
    expect(BikeBookUpdateWorker).to have_enqueued_job
  end

  it "Doesn't break if the bike isn't on bikebook" do 
    bike = FactoryGirl.create(:bike)
    BikeBookUpdateWorker.new.perform(bike.id)
  end

  it "grabs the components and doesn't overwrite components nothing if the bike isn't on bikebook" do 
    manufacturer = FactoryGirl.create(:manufacturer, name: "SE Bikes")
    bike = FactoryGirl.create(:bike,
      manufacturer_id: manufacturer.id,
      year: 2014,
      frame_model: "Draft"
    )
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
     "seatpost"].each { |name| FactoryGirl.create(:ctype, name: name)}
    component1 = FactoryGirl.create(:component,
      bike: bike, ctype_id: Ctype.find_by_slug('fork').id,
      description: "SE straight Leg Hi-Ten w/ Fender Mounts & Wide Tire Clearance")
    component1.is_stock.should be_false
    component2 = FactoryGirl.create(:component,
      bike: bike, ctype_id: Ctype.find_by_slug('crankset').id,
      description: "Sweet cranks")
    BikeBookUpdateWorker.new.perform(bike.id)
    bike.reload
    bike.components.count.should be > 10
    bike.components.where(id: component1.id).first.is_stock.should be_true
    bike.components.where(id: component2.id).first.is_stock.should be_false
    bike.components.where(ctype_id: component2.ctype_id).count.should eq(1)
  end

  

end