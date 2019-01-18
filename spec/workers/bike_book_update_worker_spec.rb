require 'spec_helper'

describe BikeBookUpdateWorker do
  it { is_expected.to be_processed_in :updates }

  it 'enqueues listing ordering job' do
    BikeBookUpdateWorker.perform_async
    expect(BikeBookUpdateWorker).to have_enqueued_sidekiq_job
  end

  it "Doesn't break if the bike isn't on bikebook" do
    bike = FactoryBot.create(:bike)
    BikeBookUpdateWorker.new.perform(bike.id)
  end

  it "grabs the components and doesn't overwrite components nothing if the bike isn't on bikebook" do
    manufacturer = FactoryBot.create(:manufacturer, name: 'SE Bikes')
    bike = FactoryBot.create(:bike,
                              manufacturer_id: manufacturer.id,
                              year: 2014,
                              frame_model: 'Draft'
                             )
    ['fork',
     'crankset',
     'pedals',
     'chain',
     'wheel',
     'tire',
     'headset',
     'handlebar',
     'stem',
     'grips/tape',
     'saddle',
     'seatpost'].each { |name| FactoryBot.create(:ctype, name: name) }
    component1 = FactoryBot.create(:component,
                                    bike: bike, ctype_id: Ctype.friendly_find('fork').id,
                                    description: 'SE straight Leg Hi-Ten w/ Fender Mounts & Wide Tire Clearance')
    expect(component1.is_stock).to be_falsey
    component2 = FactoryBot.create(:component,
                                    bike: bike, ctype_id: Ctype.friendly_find('crankset').id,
                                    description: 'Sweet cranks')
    BikeBookUpdateWorker.new.perform(bike.id)
    bike.reload
    expect(bike.components.count).to eq(14)
    expect(bike.components.where(id: component1.id).first.is_stock).to be_truthy
    expect(bike.components.where(id: component2.id).first.is_stock).to be_falsey
    expect(bike.components.where(is_stock: false).count).to eq(1)
    expect(bike.components.where(ctype_id: component2.ctype_id).count).to eq(1)
    expect(Ctype.pluck(:id) - bike.components.pluck(:ctype_id)).to eq([])
  end
end
