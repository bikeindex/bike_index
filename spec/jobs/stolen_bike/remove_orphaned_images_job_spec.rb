require "rails_helper"

RSpec.describe StolenBike::RemoveOrphanedImagesJob, type: :lib do
  include_context :scheduled_job
  include_examples :scheduled_job_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority" # overrides default
    expect(described_class.frequency).to be > 20.hours
  end

  describe "perform" do
    let(:instance) { described_class.new }

    it "enqueues for images that have been created in the past day"

    context "passed an ID" do
      
      it "deletes the orphaned records and also the alert_image" do

      end
    end
  end
end
