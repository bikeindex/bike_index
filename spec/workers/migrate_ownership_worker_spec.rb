require "rails_helper"

RSpec.describe MigrateOwnershipWorker, type: :job do
  let(:instance) { described_class.new }

  let(:ownership) { FactoryBot.create(:ownership) }
  let!(:bike) { ownership.bike }
  it "updates the " do
    bike.reload
    expect(bike.soon_current_ownership_id).to be_blank
    instance.perform(bike.id)
    bike.reload
    expect(bike.soon_current_ownership_id).to eq ownership.id
  end
end
