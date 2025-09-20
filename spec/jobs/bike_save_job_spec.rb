require "rails_helper"

RSpec.describe BikeSaveJob, type: :job do
  let(:instance) { described_class.new }

  let(:bike) { FactoryBot.create(:bike, updated_at: Time.current - 1.hour) }
  it "saves" do
    expect(bike.reload.updated_at).to be < Time.current - 10.minutes
    instance.perform(bike.id)
    expect(bike.reload.updated_at).to be_within(1).of Time.current
  end
end
