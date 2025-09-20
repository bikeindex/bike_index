require "rails_helper"

RSpec.describe BikeSaveJob, type: :job do
  let(:instance) { described_class.new }

  let(:bike) { FactoryBot.create(:bike, updated_at: 1.hour.ago) }
  it "saves" do
    expect(bike.reload.updated_at).to be < 10.minutes.ago
    instance.perform(bike.id)
    expect(bike.reload.updated_at).to be_within(1).of Time.current
  end
end
