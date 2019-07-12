require "rails_helper"

RSpec.describe TsvCreatorWorker, type: :job do
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority"
    expect(described_class.frequency).to eq 24.hours
  end

  it "sends tsv creator the method it's passed" do
    expect_any_instance_of(TsvCreator).to receive(:create_stolen).with(true).and_return(true)
    expect_any_instance_of(TsvCreator).to receive(:create_stolen).with(false).and_return(true)
    described_class.new.perform("create_stolen", true)
  end

  describe "enqueue_creation" do
    let(:target_args) do
      [
        ["create_manufacturer"],
        ["create_stolen_with_reports", true],
        ["create_stolen", true],
        ["create_daily_tsvs"],
      ]
    end
    it "creates jobs for the TSV creation" do
      Sidekiq::Worker.clear_all
      expect do
        described_class.new.perform
      end.to change(described_class.jobs, :size).by(4)
      expect(described_class.jobs.map { |j| j["args"] }).to match_array(target_args)
    end
  end
end
