require "rails_helper"

RSpec.describe MigrateBlankExtraRegistrationNumberWorker, type: :job do
  let(:instance) { described_class.new }

  let(:bike) { FactoryBot.create(:bike, extra_registration_number: extra, updated_at: Time.current - 1.hour) }
  let(:extra) { " " }
  it "makes blank nil" do
    instance.perform(bike.id)
    expect(bike.reload.updated_at).to be < Time.current - 10.minutes
    expect(bike.extra_registration_number).to be_nil
  end
  context "not nil" do
    let(:extra) { "Something " }
    it "strips" do
      instance.perform(bike.id)
      expect(bike.reload.updated_at).to be < Time.current - 10.minutes
      expect(bike.extra_registration_number).to eq "Something"
    end
  end
end
