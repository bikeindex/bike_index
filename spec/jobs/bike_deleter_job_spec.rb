require "rails_helper"

RSpec.describe BikeDeleterJob, type: :job do
  let(:instance) { described_class.new }

  let(:ownership) { FactoryBot.create(:ownership) }
  let!(:bike) { ownership.bike }
  it "deletes a bike and associations, doesn't error if bike is deleted already" do
    expect {
      instance.perform(bike.id)
      # Running it again doesn't error
      instance.perform(bike.id)
    }.to change(Bike, :count).by(-1).and change(Ownership, :count).by 0
    expect(Bike.unscoped.find_by_id(bike.id)).to be_present
    bike.reload
    expect(bike.deleted?).to be_truthy
    # And it didn't delete ownership
    expect(Ownership.where(id: ownership.id).count).to eq 1
  end

  context "really delete" do
    let(:bike_id) { bike.id }
    it "really deletes the bike and ownership" do
      expect {
        instance.perform(bike_id, true)
        # Running it again doesn't error
        instance.perform(bike_id, true)
      }.to change(Bike, :count).by(-1).and change(Ownership, :count).by(-1)
      expect(Bike.unscoped.find_by_id(bike_id)).to be_nil
      expect(Ownership.where(id: ownership.id).count).to eq 0
    end
  end
end
