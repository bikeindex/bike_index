require 'spec_helper'

describe SaveBikeVersionWorker do
  it { should be_processed_in :versioner }
  
  it "sends the bike" do
    bike = FactoryGirl.create(:bike)
    SaveBikeVersionWorker.perform_async(bike.id)
    expect(SaveBikeVersionWorker).to have_enqueued_job(bike.id)
  end

  it "creates pretty json without registration_updated_at" do 
    bike = FactoryGirl.create(:bike)
    bike.update_attribute :updator_id, 42
    result = SaveBikeVersionWorker.new.perform(bike.id)
    result = JSON.parse(result)
    result['updator_id'].should eq(42)
    result['registration_updated_at'].should_not be_present
  end

end
