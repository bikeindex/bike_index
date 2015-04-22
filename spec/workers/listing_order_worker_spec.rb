require 'spec_helper'

describe ListingOrderWorker do
  it { should be_processed_in :updates }

  it "enqueues listing ordering job" do
    ListingOrderWorker.perform_async
    expect(ListingOrderWorker).to have_enqueued_job
  end

  it "enqueues version worker, doesn't reset paint accidentally" do 
    paint = FactoryGirl.create(:paint)
    bike = FactoryGirl.create(:bike, paint_id: paint.id)
    ownership = FactoryGirl.create(:ownership, bike: bike)
    ListingOrderWorker.new.perform(bike.id)
    bike.reload.paint.should eq(paint)
    expect(AfterBikeSaveWorker).to have_enqueued_job(bike.id)
    expect(AfterUserChangeWorker).to have_enqueued_job(ownership.creator.id)
  end

  it "doesn't break if it isn't a bike" do 
    ListingOrderWorker.new.perform(96)
    expect(AfterBikeSaveWorker).to have_enqueued_job(96)
  end

end