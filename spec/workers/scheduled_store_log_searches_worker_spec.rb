require "rails_helper"

RSpec.describe ScheduledStoreLogSearchesWorker, type: :job do
  let(:instance) { described_class.new }
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

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
    end
  end
end
