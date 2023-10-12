require "rails_helper"

RSpec.describe DuplicateBikeFinderWorker, type: :job do
  let(:instance) { described_class.new }

  it "takes a bike id and search for groups, ignoring any less than 5 chars" do
    bike1 = FactoryBot.create(:bike, serial_number: "applejacks cereal cross")
    bike1.create_normalized_serial_segments
    bike2 = FactoryBot.create(:bike, serial_number: "applejacks Funtimes cross")
    bike2.create_normalized_serial_segments
    expect {
      instance.perform(bike1.id)
    }.to change(DuplicateBikeGroup, :count).by 1

    expect {
      duplicate_group = bike1.normalized_serial_segments.first.duplicate_bike_group
      expect(bike2.normalized_serial_segments.first.duplicate_bike_group).to eq(duplicate_group)
    }.to_not change(DuplicateBikeGroup, :count)
  end

  context "not current bikes" do
    let!(:bike1) { FactoryBot.create(:bike, serial_number: "Y0AAS-FFFFF") }
    before do
      bike1.create_normalized_serial_segments
      bike2.create_normalized_serial_segments
    end
    context "user_hidden" do
      let!(:bike2) { FactoryBot.create(:bike, serial_number: "Y0AASFFFFF", user_hidden: true) }
      it "creates for user_hidden" do
        expect(DuplicateBikeGroup.count).to eq 0
        instance.perform(bike2.id)
        expect(bike2.reload.normalized_serial_segments.first.duplicate_bike_group).to be_present
        expect(bike2.duplicate_bikes.pluck(:id)).to eq([bike1.id])
        expect(DuplicateBikeGroup.count).to eq 1
      end
    end
    context "example" do
      let!(:bike2) { FactoryBot.create(:bike, serial_number: "Y0AASFFFFF", example: true) }
      it "doesn't create" do
        expect(DuplicateBikeGroup.count).to eq 0
        instance.perform(bike2.id)
        expect(bike2.reload.normalized_serial_segments.count).to eq 0
        expect(DuplicateBikeGroup.count).to eq 0
      end
    end
    context "likely_spam" do
      let!(:bike2) { FactoryBot.create(:bike, serial_number: "Y0AASFFFFF", likely_spam: true) }
      it "doesn't create" do
        expect(DuplicateBikeGroup.count).to eq 0
        instance.perform(bike2.id)
        expect(bike2.reload.normalized_serial_segments.count).to eq 0
        expect(DuplicateBikeGroup.count).to eq 0
      end
    end
    context "deletion" do
      let!(:bike2) { FactoryBot.create(:bike, serial_number: "Y0A ASF FFFF") }
      it "deletes segments on deletion" do
        expect(DuplicateBikeFinderWorker.jobs.count).to eq 0 # TODO: remove after tests pass
        expect(DuplicateBikeGroup.count).to eq 0
        instance.perform(bike2.id)
        expect(bike2.reload.normalized_serial_segments.count).to eq 4
        expect(bike2.duplicate_bikes.pluck(:id)).to eq([bike1.id])
        expect(DuplicateBikeGroup.count).to eq 1
        bike2.destroy
        # Bike destroy enqueues the duplicate bike finder
        expect(DuplicateBikeFinderWorker.jobs.count).to eq 1
        DuplicateBikeFinderWorker.drain
        expect(bike2.reload.normalized_serial_segments.count).to eq 0
        expect(DuplicateBikeGroup.count).to eq 0
      end
    end
  end

  context "only one match" do
    it "doesn't create a duplicate" do
      bike = FactoryBot.create(:bike, serial_number: "applejacks")
      bike.create_normalized_serial_segments
      expect(DuplicateBikeGroup.count).to eq 0
      instance.perform(bike.id)
      expect(bike.normalized_serial_segments.first.duplicate_bike_group).to_not be_present
      expect(DuplicateBikeGroup.count).to eq 0
    end
  end

  context "existing duplicate bike group" do
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
      instance.perform(bike3.id)
      expect(bike3.normalized_serial_segments.first.duplicate_bike_group).to eq(duplicate_group)
      duplicate_group.reload
      expect(duplicate_group.added_bike_at).to_not eq(t)
    end
  end

  context "bike gone" do
    it "doesn't explode" do
      expect {
        instance.perform(12121212)
      }.to_not raise_error
    end
  end
end
