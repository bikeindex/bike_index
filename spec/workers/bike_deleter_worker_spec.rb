require "rails_helper"

RSpec.describe BikeDeleterWorker, type: :job do
  let(:instance) { described_class.new }

  let(:ownership) { FactoryBot.create(:ownership) }
  let!(:bike) { ownership.bike }
  it "deletes a bike and associations, doesn't error if bike is deleted already" do
    expect {
      instance.perform(bike.id)
    }.to change(Bike, :count).by(-1)
    instance.perform(bike.id)
    bike.reload
    expect(bike.deleted?).to be_truthy
  end
end
