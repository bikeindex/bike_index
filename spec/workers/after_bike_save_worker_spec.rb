require 'spec_helper'

describe AfterBikeSaveWorker do
  it { should be_processed_in :afterwards }
  
  it "sends a delete hash if the bike is hidden" do
    bike = FactoryGirl.create(:bike, hidden: true)
    WebhookRunner.any_instance.should_receive(:after_bike_update).with(bike.id).once
    result = JSON.parse(AfterBikeSaveWorker.new.perform(bike.id))
    result['deleted'].should eq(true)
  end

  it "doesn't send a delete hash if the bike is user hidden" do
    ownership = FactoryGirl.create(:ownership, user_hidden: true)
    bike = ownership.bike 
    bike.update_attribute :hidden, true
    bike.reload.user_hidden.should be_true
    WebhookRunner.any_instance.should_receive(:after_bike_update).with(bike.id).once
    result = JSON.parse(AfterBikeSaveWorker.new.perform(bike.id))
    result['deleted'].should_not be_present
  end

  it "creates pretty json without registration_updated_at" do 
    ENV['VERSIONER_LOCATION'] = 'spec/fixtures'
    bike = FactoryGirl.create(:bike)
    bike.update_attribute :updator_id, 42
    WebhookRunner.any_instance.should_receive(:after_bike_update).with(bike.id).once
    r = AfterBikeSaveWorker.new.perform(bike.id)
    result = JSON.parse(r)
    result['updator_id'].should eq(42)
    result['registration_updated_at'].should_not be_present
    f = File.open(Rails.root.to_s + "/spec/fixtures/bikes/#{bike.id}.json")
    f.read.should eq(r)
    ENV['VERSIONER_LOCATION'] = nil
  end

  it "doesn't create a new file if one doesn't exist for deleted bikes, returns delete hash" do 
    ENV['VERSIONER_LOCATION'] = 'spec/fixtures'
    id = 1111
    WebhookRunner.any_instance.should_receive(:after_bike_update).with(id).once
    r = AfterBikeSaveWorker.new.perform(id)
    result = JSON.parse(r)
    result['deleted'].should be_true
    File.exist?(Rails.root.to_s + "/spec/fixtures/bikes/#{id}.json").should be_false
    ENV['VERSIONER_LOCATION'] = nil
  end

end


