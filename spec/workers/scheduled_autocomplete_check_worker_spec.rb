require "rails_helper"

RSpec.describe ScheduledAutocompleteCheckWorker, type: :job do
  let(:instance) { described_class.new }
  context "stubbed Autocomplete::Loader" do
    # So that it doesn't actually run
    before do
      allow_any_instance_of(described_class).to receive(:too_few_autocomplete_manufacturers?) { false }
    end
    include_context :scheduled_worker
    include_examples :scheduled_worker_tests
  end

  describe "perform" do
    before { FactoryBot.create(:manufacturer) }
    it "throws an error if there are no manufacturers" do
      Autocomplete::Loader.clear_redis
      Sidekiq::Worker.clear_all
      expect {
        instance.perform
      }.to raise_error(/manufacturer/i)
      expect(AutocompleteLoaderWorker.jobs.count).to eq 1
    end
    context "with manufacturers" do
      it "doesn't throw and error or enqueue" do
        Autocomplete::Loader.load_all(["Manufacturer"])
        expect(Autocomplete::Loader.frame_mnfg_count).to be > 0
        Sidekiq::Worker.clear_all
        instance.perform
        expect(AutocompleteLoaderWorker.jobs.count).to eq 0
      end
    end
  end
end
