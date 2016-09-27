require 'spec_helper'

describe AfterBikeSaveWorker do
  it { is_expected.to be_processed_in :updates }

  describe 'enqueuing jobs' do
    let(:bike_id) { FactoryGirl.create(:ownership, user_hidden: true).bike_id }
    it 'enqueues the duplicate_bike_finder_worker' do
      expect do
        AfterBikeSaveWorker.new.perform(bike_id)
      end.to change(DuplicateBikeFinderWorker.jobs, :size).by 1
    end
  end

  it "doesn't break if unable to find bike" do
    AfterBikeSaveWorker.new.perform(96)
  end

  context 'changed listing order' do
    it 'updates the listing order' do
      bike = FactoryGirl.create(:bike)
      bike.update_attribute :listing_order, -22
      AfterBikeSaveWorker.new.perform(bike.id)
      bike.reload
      expect(bike.listing_order).to eq bike.get_listing_order
    end
  end

  context 'unchanged listing order' do
    it 'does not update the listing order or enqueue afterbikesave' do
      bike = FactoryGirl.create(:bike)
      bike.update_attribute :listing_order, bike.get_listing_order
      expect_any_instance_of(Bike).to_not receive(:update_attribute)
      AfterBikeSaveWorker.new.perform(bike.id)
    end
  end
end
