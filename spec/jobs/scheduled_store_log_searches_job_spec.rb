require "rails_helper"

RSpec.describe ScheduledStoreLogSearchesJob, type: :job do
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  let(:instance) { described_class.new }

  describe "perform" do
    let!(:organization) { FactoryBot.create(:organization, name: "Hogwarts") }
    let(:log_line) { 'I, [2023-10-23T13:18:57.628282 #444563]  INFO -- : [74dbf83c-07ca-4bcf-ac82-aa9c6d9ab1f4] {"method":"GET","path":"/o/hogwarts/impound_records","format":"html","controller":"Organized::ImpoundRecordsController","action":"index","status":200,"duration":49.0,"view":28.72,"db":10.93,"remote_ip":"11.11.22.11","u_id":111,"params":{"organization_id":"hogwarts"},"@timestamp":"2023-10-23T13:18:57.628Z","@version":"1","message":"[200] GET /o/hogwarts/impound_records (Organized::ImpoundRecordsController#index)"}' }
    before { allow_any_instance_of(described_class).to receive(:get_log_line) { log_line } }
    it "parses a log line" do
      expect(LoggedSearch.count).to eq 0
      logged_search = instance.perform(true)
      expect(LoggedSearch.count).to eq 1
      expect(logged_search.log_line).to eq log_line
      expect(logged_search.endpoint).to eq "org_impounded"
      expect(logged_search.stolenness).to eq "impounded"
      expect(logged_search.organization_id).to eq organization.id
      expect(logged_search.user_id).to eq 111
      expect(logged_search.unprocessed?).to be_truthy
      expect(ProcessLoggedSearchJob).to have_enqueued_sidekiq_job(logged_search.id)
    end
  end

  describe "enqueue_workers" do
    before { Sidekiq::Job.clear_all }
    it "enqueues workers for all the log lines" do
      allow(LogSearcher::Reader).to receive(:log_lines_in_redis) { 50 }
      expect(described_class.jobs.count).to eq 0
      instance.perform
      expect(described_class.jobs.count).to eq 50
    end
    context "over 1000 log lines" do
      it "enqueues 1k and re-enqueues scheduler" do
        allow(LogSearcher::Reader).to receive(:log_lines_in_redis) { 5000 }
        expect(described_class.jobs.count).to eq 0
        instance.perform
        # Not testing precisely that MAX_W enqueued with true, 1 enqueued to reschedule - but good enough
        expect(described_class.jobs.count).to eq ScheduledStoreLogSearchesJob::MAX_W + 1
      end
    end
  end
end
