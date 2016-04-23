require 'spec_helper'

describe AfterBikeSaveWorker do
  it { is_expected.to be_processed_in :afterwards }

  it 'sends a delete hash if the bike is hidden' do
    bike = FactoryGirl.create(:bike, hidden: true)
    result = JSON.parse(AfterBikeSaveWorker.new.perform(bike.id))
    expect(result['deleted']).to eq(true)
  end

  it "doesn't send a delete hash if the bike is user hidden" do
    ownership = FactoryGirl.create(:ownership, user_hidden: true)
    bike = ownership.bike
    bike.update_attribute :hidden, true
    expect(bike.reload.user_hidden).to be_truthy
    result = JSON.parse(AfterBikeSaveWorker.new.perform(bike.id))
    expect(result['deleted']).not_to be_present
  end

  it 'enqueues the duplicate_bike_finder_worker' do
    ownership = FactoryGirl.create(:ownership, user_hidden: true)
    expect do
      JSON.parse(AfterBikeSaveWorker.new.perform(ownership.bike_id))
    end.to change(DuplicateBikeFinderWorker.jobs, :size).by(1)
  end

  it 'creates pretty json without registration_updated_at, sends webhook runner' do
    ENV['VERSIONER_LOCATION'] = 'spec/fixtures'
    bike = FactoryGirl.create(:bike)
    bike.update_attribute :updator_id, 42
    expect_any_instance_of(WebhookRunner).to receive(:after_bike_update).with(bike.id).once
    r = AfterBikeSaveWorker.new.perform(bike.id)
    result = JSON.parse(r)
    expect(result['updator_id']).to eq(42)
    expect(result['registration_updated_at']).not_to be_present
    f = File.open(Rails.root.to_s + "/spec/fixtures/bikes/#{bike.id}.json")
    expect(f.read).to eq(r)
    ENV['VERSIONER_LOCATION'] = nil
  end

  it "doesn't create a new file if one doesn't exist for deleted bikes, returns delete hash, doesn't run webhook runner" do
    ENV['VERSIONER_LOCATION'] = 'spec/fixtures'
    id = 1111
    expect_any_instance_of(WebhookRunner).not_to receive(:after_bike_update).with(id).once
    r = AfterBikeSaveWorker.new.perform(id)
    result = JSON.parse(r)
    expect(result['deleted']).to be_truthy
    expect(File.exist?(Rails.root.to_s + "/spec/fixtures/bikes/#{id}.json")).to be_falsey
    ENV['VERSIONER_LOCATION'] = nil
  end
end
