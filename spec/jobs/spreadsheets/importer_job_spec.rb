require "rails_helper"

RSpec.describe Spreadsheets::ImporterJob, type: :job do
  include_context :scheduled_job
  include_examples :scheduled_job_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority"
    expect(described_class.frequency).to eq 24.hours
  end

  describe "perform with no args" do
    it "enqueues a job for each importer" do
      Sidekiq::Job.clear_all
      expect { described_class.new.perform }.to change(described_class.jobs, :size).by(3)
      expect(described_class.jobs.map { |j| j["args"] })
        .to match_array([["manufacturers"], ["primary_activities"], ["components"]])
    end
  end

  describe "perform with a name" do
    let(:csv) do
      "name,alternate_name,website,makes_frames,ebike_only,open_year,close_year,logo_url\n" \
        "Mualani,,https://example.com,true,false,2001,,\n"
    end
    before { allow_any_instance_of(described_class).to receive(:download).and_return(csv) }

    it "downloads and imports the named spreadsheet" do
      expect { described_class.new.perform("manufacturers") }.to change(Manufacturer, :count).by 1
      expect(Manufacturer.friendly_find("Mualani")).to be_present
    end
  end
end
