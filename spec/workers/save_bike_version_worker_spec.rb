require 'spec_helper'

describe SaveBikeVersionWorker do
  it { should be_processed_in :versioner }
  
  it "sends the bike" do
    bike = FactoryGirl.create(:bike)
    SaveBikeVersionWorker.perform_async(bike.id)
    expect(SaveBikeVersionWorker).to have_enqueued_job(bike.id)
  end

  it "creates pretty json" do 
    bike = FactoryGirl.create(:bike)
    bike.update_attribute :updator_id, 42
    result = SaveBikeVersionWorker.new.perform(bike.id)
    JSON.parse(result)['updator_id'].should eq(42)
  end

end
