require "rails_helper"

RSpec.describe ImpoundExpirationWorker, type: :job do
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority" # overrides default
    expect(described_class.frequency).to be > 23.hours
  end

  describe "perform" do
    let(:impound_configuration) { FactoryBot.create(:impound_configuration, expiration_period_days: 45) }
    let(:organization) { impound_configuration.organization }
    let!(:impound_record1) { FactoryBot.create(:impound_record, :with_organization, organization: organization, created_at: Time.current - 46.days) }
    let!(:impound_record2) { FactoryBot.create(:impound_record, :with_organization, organization: organization, created_at: Time.current - 44.days) }
    it "schedules all the workers" do
      expect(impound_record1.reload.bike.created_at).to be < Time.current - 45.days
      Sidekiq::Worker.clear_all
      expect {
        described_class.new.perform
      }.to change(ImpoundRecordUpdate, :count).by 1
      expect(ProcessImpoundUpdatesWorker.jobs.count).to eq 1
      expect(ProcessImpoundUpdatesWorker.jobs.map { |j| j["args"] }.last.flatten).to eq([impound_record1.id])
      ProcessImpoundUpdatesWorker.drain
      expect(impound_record1.reload.status).to eq "expired"
      expect(impound_record1.active?).to be_falsey
      expect(impound_record1.bike.deleted?).to be_truthy

      expect(impound_record2.reload.status).to eq "current"
      expect(impound_record2.active?).to be_truthy
      expect(impound_record2.bike.deleted?).to be_falsey
    end
  end
end
