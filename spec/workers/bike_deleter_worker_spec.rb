require "rails_helper"

RSpec.describe BikeDeleterWorker, type: :job do
  let(:subject) { BikeDeleterWorker }
  let(:instance) { subject.new }

  let(:ownership) { FactoryBot.create(:ownership) }
  let!(:bike) { ownership.bike }
  it "deletes a bike and associations, doesn't error if bike is deleted already" do
    expect do
      instance.perform(bike.id)
    end.to change(Ownership, :count).by(-1)
    instance.perform(bike.id)
  end
end
