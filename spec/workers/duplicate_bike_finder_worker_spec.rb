require 'spec_helper'

describe DuplicateBikeFinderWorker do
  it { is_expected.to be_processed_in :afterwards }

  it 'takes a bike id and search for groups' do
    bike1 = FactoryGirl.create(:bike, serial_number: 'applejacks cereal')
    bike1.create_normalized_serial_segments
    bike2 = FactoryGirl.create(:bike, serial_number: 'applejacks Funtimes')
    bike2.create_normalized_serial_segments
    DuplicateBikeFinderWorker.new.perform(bike1.id)
    duplicate_group = bike1.normalized_serial_segments.first.duplicate_bike_group
    expect(bike2.normalized_serial_segments.first.duplicate_bike_group).to eq(duplicate_group)
  end

  it "doesn't create a duplicate if only one match" do
    bike = FactoryGirl.create(:bike, serial_number: 'applejacks')
    bike.create_normalized_serial_segments
    DuplicateBikeFinderWorker.new.perform(bike.id)
    expect(bike.normalized_serial_segments.first.duplicate_bike_group).to_not be_present
  end

  it 'adds a bike to an existing duplicate bike group' do
    bike1 = FactoryGirl.create(:bike, serial_number: 'applejacks')
    bike1.create_normalized_serial_segments
    bike2 = FactoryGirl.create(:bike, serial_number: 'applejacks')
    bike2.create_normalized_serial_segments
    t = Time.at(1441314105)
    duplicate_group = DuplicateBikeGroup.create(added_bike_at: t)
    expect(duplicate_group.added_bike_at).to eq(t)
    bike1.normalized_serial_segments.first.update_attribute :duplicate_bike_group_id, duplicate_group.id
    bike2.normalized_serial_segments.first.update_attribute :duplicate_bike_group_id, duplicate_group.id
    bike3 = FactoryGirl.create(:bike, serial_number: 'applejacks')
    bike3.create_normalized_serial_segments
    DuplicateBikeFinderWorker.new.perform(bike3.id)
    expect(bike3.normalized_serial_segments.first.duplicate_bike_group).to eq(duplicate_group)
    duplicate_group.reload
    expect(duplicate_group.added_bike_at).to_not eq(t)
  end
end
