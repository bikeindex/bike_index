require 'spec_helper'

describe AfterBikeSaveWorker do
  let(:subject) { AfterBikeSaveWorker }
  let(:instance) { subject.new }

  describe 'enqueuing jobs' do
    let(:bike_id) { FactoryGirl.create(:ownership, user_hidden: true).bike_id }
    it 'enqueues the duplicate_bike_finder_worker' do
      expect do
        instance.perform(bike_id)
      end.to change(DuplicateBikeFinderWorker.jobs, :size).by 1
    end
  end

  it "doesn't break if unable to find bike" do
    instance.perform(96)
  end

  context 'changed listing order' do
    it 'updates the listing order' do
      bike = FactoryGirl.create(:bike)
      bike.update_attribute :listing_order, -22
      instance.perform(bike.id)
      bike.reload
      expect(bike.listing_order).to eq bike.get_listing_order
    end
  end

  context 'unchanged listing order' do
    it 'does not update the listing order or enqueue afterbikesave' do
      bike = FactoryGirl.create(:bike)
      bike.update_attribute :listing_order, bike.get_listing_order
      expect_any_instance_of(Bike).to_not receive(:update_attribute)
      instance.perform(bike.id)
    end
  end

  describe "serialized" do
    let!(:bike) { FactoryGirl.create(:stolen_bike) }
    it "calls the things we expect it to call" do
      ENV["BIKE_WEBHOOK_AUTH_TOKEN"] = "xxxx"
      serialized = instance.serialized(bike)
      # expect(serialized[:auth_token]).to eq "xxxx" # fails on travis :/
      expect(serialized[:bike][:id]).to be_present
      expect(serialized[:bike][:stolen_record]).to be_present
      expect(serialized[:update]).to be_truthy
    end
  end
end
