require "rails_helper"

RSpec.describe CleanBParamsJob, type: :job do
  include_context :scheduled_job
  include_examples :scheduled_job_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority" # overrides default
    expect(described_class.frequency).to be > 23.hours
  end

  describe "perform" do
    let(:stale) { Time.current - 4.days }
    let!(:b_param_with_values) { FactoryBot.create(:b_param, updated_at: stale) }
    let(:bike) { FactoryBot.create(:bike) }
    let!(:b_param_with_bike) { FactoryBot.create(:b_param, created_bike_id: bike.id, updated_at: stale) }
    let!(:b_param_with_recent_bike) { FactoryBot.create(:b_param, created_bike_id: bike.id, updated_at: Time.current - 2.hours) }
    let!(:b_param_blank) { BParam.create(origin: "register_flow", params: {bike: {}}.as_json, updated_at: stale) }
    let!(:b_param_blank_recent) { BParam.create(origin: "register_flow", params: {bike: {}}.as_json) }

    it "deletes stale created-bike and never-submitted registrations" do
      expect(BParam.without_bike_values.pluck(:id)).to match_array([b_param_blank.id, b_param_blank_recent.id])
      expect { described_class.new.perform }.to change(BParam, :count).by(-2)
      expect(BParam.pluck(:id)).to match_array([b_param_with_values.id, b_param_with_recent_bike.id, b_param_blank_recent.id])
    end

    context "with an e-vehicle acknowledgment" do
      let!(:acknowledgment) do
        FactoryBot.create(:registration_sequence_acknowledgment, b_param: b_param_with_bike, bike:)
      end

      it "sweeps the registration, leaving the acknowledgment record standing" do
        expect { described_class.new.perform }.to change(BParam, :count).by(-2)
        expect(acknowledgment.reload.bike_id).to eq bike.id
        expect(acknowledgment.acknowledgment_text).to be_present # read off the sequence
      end
    end
  end
end
