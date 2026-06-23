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
    it "loads autocomplete inline and doesn't raise" do
      Autocomplete::Loader.clear_redis
      expect(instance.too_few_autocomplete_manufacturers?).to be_truthy
      instance.perform
      expect(instance.too_few_autocomplete_manufacturers?).to be_falsey
    end
    context "when loading doesn't resolve the shortage" do
      it "raises" do
        allow(instance).to receive(:too_few_autocomplete_manufacturers?) { true }
        expect { instance.perform }.to raise_error(/manufacturer/i)
      end
    end
    context "with enough manufacturers" do
      it "doesn't load or raise" do
        Autocomplete::Loader.load_all(["Manufacturer"])
        expect(Autocomplete::Loader.frame_mnfg_count).to be > 0
        expect_any_instance_of(AutocompleteLoaderJob).not_to receive(:perform)
        instance.perform
      end
    end
  end
end
