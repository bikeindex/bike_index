require 'spec_helper'

describe ListingOrderWorker do
  it { should be_processed_in :updates }

  it 'enqueues listing ordering job' do
    ListingOrderWorker.perform_async
    expect(ListingOrderWorker).to have_enqueued_job
  end

  it "enqueues version worker, doesn't reset paint accidentally" do 
    paint = FactoryGirl.create(:paint)
    bike = FactoryGirl.create(:bike, paint_id: paint.id)
    ownership = FactoryGirl.create(:ownership, bike: bike)
    ListingOrderWorker.new.perform(bike.id)
    bike.reload
    bike.paint.should eq(paint)
  end

  it "doesn't break if it isn't a bike" do 
    ListingOrderWorker.new.perform(96)
  end

  context 'changed listing order' do
    it 'updates the listing order and enqueues afterbikesave' do
      bike = FactoryGirl.create(:bike)
      bike.update_attribute :listing_order, -22
      ListingOrderWorker.new.perform(bike.id)
      bike.reload
      expect(bike.listing_order).to eq bike.get_listing_order
      expect(AfterBikeSaveWorker).to have_enqueued_job(bike.id)
    end
  end

  context 'unchanged listing order' do
    it 'does not update the listing order or enqueue afterbikesave' do
      bike = FactoryGirl.create(:bike)
      bike.update_attribute :listing_order, bike.get_listing_order
      ListingOrderWorker.new.perform(bike.id)
      expect(AfterBikeSaveWorker).to_not have_enqueued_job(bike.id)
    end
  end
end