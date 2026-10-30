require "rails_helper"

RSpec.describe UpdateLoggedSearchCountsJob, type: :job do
  include_context :scheduled_job
  include_examples :scheduled_job_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "droppable"
    expect(described_class.frequency).to be > 45.minutes
  end

  describe "perform" do
    let!(:logged_search) { FactoryBot.create(:logged_search, endpoint: :web_marketplace, request_at: Time.current) }

    it "stores today's counts" do
      described_class.new.perform
      expect(Counts.logged_searches([Date.current])[Date.current]["web_marketplace"]).to eq 1
    end
  end
end
