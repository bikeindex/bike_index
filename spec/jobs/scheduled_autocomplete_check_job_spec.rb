require "rails_helper"

RSpec.describe ScheduledAutocompleteCheckJob, type: :job do
  let(:instance) { described_class.new }
  context "stubbed Autocomplete::Loader" do
    # So that it doesn't actually run
    before do
      allow_any_instance_of(described_class).to receive(:too_few_autocomplete_manufacturers?) { false }
    end
    include_context :scheduled_job
    include_examples :scheduled_job_tests
  end

  describe "perform" do
    before { FactoryBot.create(:manufacturer) }
    it "throws an error if there are no manufacturers" do
      Autocomplete::Loader.clear_redis
      Sidekiq::Job.clear_all
      expect {
        instance.perform
      }.to raise_error(/manufacturer/i)
      expect(AutocompleteLoaderJob.jobs.count).to eq 1
    end
    context "with manufacturers" do
      it "doesn't throw and error or enqueue" do
        Autocomplete::Loader.load_all(["Manufacturer"])
        expect(Autocomplete::Loader.frame_mnfg_count).to be > 0
        Sidekiq::Job.clear_all
        instance.perform
        expect(AutocompleteLoaderJob.jobs.count).to eq 0
      end
    end
  end
end
