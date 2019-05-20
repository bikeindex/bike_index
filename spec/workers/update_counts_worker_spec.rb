require "spec_helper"

describe UpdateCountsWorker, type: :lib do
  let(:subject) { UpdateCountsWorker }
  let(:instance) { subject.new }
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  it "is the correct queue and frequency" do
    expect(subject.sidekiq_options["queue"]).to eq "low_priority" # overrides default
    expect(subject.frequency).to be > 45.minutes
  end

  describe "perform" do
    let!(:bike) { FactoryBot.create(:bike) }
    let!(:stolen_bike) { FactoryBot.create(:stolen_bike) }
    let!(:recovered_bike) { FactoryBot.create(:stolen_record_recovered) }
    let!(:stolen_notification) { FactoryBot.create(:stolen_notification) }

    it "updates counts in the cache" do
      instance.perform
      expect(Counts.total_bikes).to eq 4
      expect(Counts.stolen_bikes).to eq 1
      expect(Counts.recoveries).to eq 2041
    end
  end
end
