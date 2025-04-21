require "rails_helper"

RSpec.describe Callbacks::AddressRecordUpdateAssociationsJob, type: :job do
  let(:instance) { described_class.new }

  let(:user) { FactoryBot.create(:user) }
  let!(:address_record) { FactoryBot.create(:address_record, user:) }

  it "assigns the user coordinates" do
    # creation enqueues this job
    expect(described_class.jobs.map { |j| j["args"] }.flatten).to eq([address_record.id])

    expect(user.latitude).to be_blank

    instance.perform(address_record.id)

    expect(user.address_record_id).to be_blank
    expect(user.reload.latitude).to eq address_record.latitude
    expect(user.longitude).to eq address_record.longitude
  end
end
