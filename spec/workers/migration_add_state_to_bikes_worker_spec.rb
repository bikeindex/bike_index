require "rails_helper"

RSpec.describe MigrationAddStateToBikesWorker, type: :job do
  let(:instance) { described_class.new }
  let(:bike) { FactoryBot.create(:stolen_bike) }
  let!(:creation_state) { FactoryBot.create(:creation_state, bike: bike) }
  it "sets stolen on the bike and creation state" do
    instance.perform(bike.id)
    bike.reload
    creation_state.reload
    expect(bike.state).to eq "state_stolen"
    expect(creation_state.state).to eq "state_stolen"
  end
  context "bike created earlier" do
    before { bike.update_attribute(:created_at, Time.current - 56.hours) }
    it "sets stolen on the bike, not creation state" do
      instance.perform(bike.id)
      bike.reload
      creation_state.reload
      expect(bike.state).to eq "state_stolen"
      expect(creation_state.state).to eq "state_with_owner"
    end
  end
end
