require "rails_helper"

RSpec.describe ImpoundExpirationJob, type: :job do
  include_context :scheduled_job
  include_examples :scheduled_job_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority" # overrides default
    expect(described_class.frequency).to be > 23.hours
  end

  describe "perform" do
    let(:impound_configuration) { FactoryBot.create(:impound_configuration, expiration_period_days: 45) }
    let(:organization) { impound_configuration.organization }
    let!(:impound_record1) { FactoryBot.create(:impound_record, :with_organization, organization: organization, created_at: Time.current - 46.days) }
    let!(:impound_record2) { FactoryBot.create(:impound_record, :with_organization, organization: organization, created_at: Time.current - 44.days) }
    let!(:impound_record3) { FactoryBot.create(:impound_record, :with_organization, organization: organization, created_at: Time.current - 100.days) }
    let(:user) { impound_record1.user }
    it "schedules all the workers" do
      expect(impound_record1.reload.bike.created_at).to be < Time.current - 45.days
      Sidekiq::Testing.inline! do
        impound_record3.impound_record_updates.create(kind: "transferred_to_new_owner",
          transfer_email: "something@stuff.com",
          user: user)
      end
      expect(impound_record3.reload.status).to eq "transferred_to_new_owner"
      expect(impound_record3.active?).to be_falsey

      Sidekiq::Job.clear_all
      expect {
        described_class.new.perform
      }.to change(ImpoundRecordUpdate, :count).by 1
      impound_record_update = ImpoundRecordUpdate.last
      expect(impound_record_update.kind).to eq "expired"
      expect(impound_record_update.impound_record_id).to eq impound_record1.id

      expect(ProcessImpoundUpdatesJob.jobs.count).to eq 1
      expect(ProcessImpoundUpdatesJob.jobs.map { |j| j["args"] }.last.flatten).to eq([impound_record1.id])
      ProcessImpoundUpdatesJob.drain
      expect(impound_record1.reload.status).to eq "expired"
      expect(impound_record1.active?).to be_falsey
      expect(impound_record1.bike.reload.deleted_at).to be_present

      expect(impound_record2.reload.status).to eq "current"
      expect(impound_record2.active?).to be_truthy
      expect(impound_record2.bike.deleted?).to be_falsey
      expect(impound_record3.reload.status).to eq "transferred_to_new_owner"
    end
  end
end
