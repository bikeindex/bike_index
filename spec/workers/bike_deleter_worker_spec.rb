require "rails_helper"

RSpec.describe BikeDeleterWorker, type: :job do
  let(:instance) { subject.new }

  let(:ownership) { FactoryBot.create(:ownership) }
  let!(:bike) { ownership.bike }
  it "deletes a bike and associations, doesn't error if bike is deleted already" do
    expect do
      described_class.new.perform(bike.id)
    end.to change(Bike, :count).by(-1)
    described_class.new.perform(bike.id)
    bike.reload
    expect(bike.deleted?).to be_truthy
  end
end
