require "rails_helper"

RSpec.describe DuplicateBikeFinderWorker, type: :job do
  it "takes a bike id and search for groups, ignoring any less than 5 chars" do
    bike1 = FactoryBot.create(:bike, serial_number: "applejacks cereal cross")
    bike1.create_normalized_serial_segments
    bike2 = FactoryBot.create(:bike, serial_number: "applejacks Funtimes cross")
    bike2.create_normalized_serial_segments
    expect {
      described_class.new.perform(bike1.id)
    }.to change(DuplicateBikeGroup, :count).by 1

    expect {
      duplicate_group = bike1.normalized_serial_segments.first.duplicate_bike_group
      expect(bike2.normalized_serial_segments.first.duplicate_bike_group).to eq(duplicate_group)
    }.to_not change(DuplicateBikeGroup, :count)
  end
  context "only one match" do
    it "doesn't create a duplicate" do
      bike = FactoryBot.create(:bike, serial_number: "applejacks")
      bike.create_normalized_serial_segments
      described_class.new.perform(bike.id)
      expect(bike.normalized_serial_segments.first.duplicate_bike_group).to_not be_present
    end
  end

  context "existing duplciate bike group" do
    it "adds a bike to an existing duplicate bike group" do
      bike1 = FactoryBot.create(:bike, serial_number: "applejacks")
      bike1.create_normalized_serial_segments
      bike2 = FactoryBot.create(:bike, serial_number: "applejacks")
      bike2.create_normalized_serial_segments
      t = Time.at(1441314105)
      duplicate_group = DuplicateBikeGroup.create(added_bike_at: t)
      expect(duplicate_group.added_bike_at).to eq(t)
      bike1.normalized_serial_segments.first.update_attribute :duplicate_bike_group_id, duplicate_group.id
      bike2.normalized_serial_segments.first.update_attribute :duplicate_bike_group_id, duplicate_group.id
      bike3 = FactoryBot.create(:bike, serial_number: "applejacks")
      bike3.create_normalized_serial_segments
      described_class.new.perform(bike3.id)
      expect(bike3.normalized_serial_segments.first.duplicate_bike_group).to eq(duplicate_group)
      duplicate_group.reload
      expect(duplicate_group.added_bike_at).to_not eq(t)
    end
  end

  context "bike gone" do
    it "doesn't explode" do
      expect {
        described_class.new.perform(12121212)
      }.to_not raise_error
    end
  end
end
