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

    context "with the template's safety rules still to agree to" do
      let(:template) { FactoryBot.create(:registration_sequence_template_active, :with_pages) }
      let(:bike_expired) { FactoryBot.create(:bike, :with_ownership) }
      let(:bike_recent) { FactoryBot.create(:bike, :with_ownership) }
      let!(:expired) { pending_on_template(bike_expired, Time.current - RegistrationSequenceAcknowledgment::TEMPLATE_PENDING_EXPIRATION - 1.day) }
      let!(:recent) { pending_on_template(bike_recent, Time.current - 1.day) }

      def pending_on_template(bike, created_at)
        b_param = FactoryBot.create(:b_param, created_bike_id: bike.id, updated_at: stale)
        FactoryBot.create(:registration_sequence_acknowledgment_pending, b_param:, bike:, registration_sequence: template, created_at:)
        b_param
      end

      it "gives up on the expired, releasing their held email" do
        Sidekiq::Job.clear_all
        described_class.new.perform
        expect(bike_expired.reload.unfinished_registration?).to be_falsey
        expect(BParam.pluck(:id)).not_to include expired.id
        expect(bike_recent.reload.unfinished_registration?).to be_truthy
        expect(BParam.pluck(:id)).to include recent.id
        expect(EmailJobs::OwnershipInvitationJob.jobs.map { it["args"] }).to eq([[bike_expired.current_ownership.id]])
      end
    end

    context "with the safety rules still to agree to" do
      let!(:b_param_pending) do
        FactoryBot.create(:b_param, created_bike_id: bike.id, updated_at: stale, origin: "register_flow",
          created_at: Time.current - BParam::TOKEN_EXPIRATION - 1.day,
          params: {bike: {manufacturer_id: 1}}.as_json)
      end
      before { FactoryBot.create(:education_course_acknowledgment_pending, b_param: b_param_pending, bike:) }

      it "keeps it, even expired, since its token is how they're resumed" do
        expect { described_class.new.perform }.to change(BParam, :count).by(-2)
        expect(BParam.pluck(:id)).to include b_param_pending.id
        expect(bike.unfinished_registration?).to be_truthy
      end
    end

    context "with an e-vehicle acknowledgment" do
      let!(:acknowledgment) do
        FactoryBot.create(:education_course_acknowledgment, b_param: b_param_with_bike, bike:)
      end

      it "sweeps the registration, leaving the acknowledgment record standing" do
        expect { described_class.new.perform }.to change(BParam, :count).by(-2)
        expect(acknowledgment.reload.bike_id).to eq bike.id
        expect(acknowledgment.acknowledgment_text).to be_present # read off the sequence
      end
    end
  end
end
