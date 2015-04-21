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
    ListingOrderWorker.new.perform(bike.id)
    bike.reload.paint.should eq(paint)
    expect(SaveBikeVersionWorker).to have_enqueued_job(bike.id)
  end

end