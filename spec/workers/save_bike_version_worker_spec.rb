require 'spec_helper'

describe SaveBikeVersionWorker do
  it { should be_processed_in :versioner }
  
  it "sends the bike" do
    bike = FactoryGirl.create(:bike)
    SaveBikeVersionWorker.perform_async(bike.id)
    expect(SaveBikeVersionWorker).to have_enqueued_job(bike.id)
  end

end
