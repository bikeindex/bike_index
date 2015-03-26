require 'spec_helper'

describe ListingOrderWorker do
  it { should be_processed_in :updates }

  it "enqueues listing ordering job" do
    ListingOrderWorker.perform_async
    expect(ListingOrderWorker).to have_enqueued_job
  end

  it "enqueues version worker" do 
    bike = FactoryGirl.create(:bike)
    ListingOrderWorker.new.perform(bike.id)
    expect(SaveBikeVersionWorker).to have_enqueued_job(bike.id)
  end

end