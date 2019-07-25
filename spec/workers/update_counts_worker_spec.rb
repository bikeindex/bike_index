require "rails_helper"

RSpec.describe UpdateCountsWorker, type: :lib do
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority" # overrides default
    expect(described_class.frequency).to be > 45.minutes
  end

  describe "perform" do
    let!(:bike) { FactoryBot.create(:bike) }
    let!(:stolen_bike) { FactoryBot.create(:stolen_bike) }
    let!(:recovered_bike) { FactoryBot.create(:stolen_record_recovered) }
    let!(:stolen_notification) { FactoryBot.create(:stolen_notification) }

    it "updates counts in the cache" do
      described_class.new.perform
      expect(Counts.total_bikes).to eq 4
      expect(Counts.stolen_bikes).to eq 1
      expect(Counts.recoveries).to eq 2041
      expect(Counts.week_creation_chart.kind_of?(Hash)).to be_truthy
    end
  end
end
