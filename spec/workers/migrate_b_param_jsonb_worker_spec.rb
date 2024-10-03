require "rails_helper"

RSpec.describe MigrateBParamJsonbWorker, type: :lib do
  let(:instance) { described_class.new }
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority" # overrides default
    expect(described_class.frequency).to be < 10.minutes
  end

  describe "perform" do
    let!(:b_param) { FactoryBot.create(:b_param, params: {bike: {owner_email: "s@t.com"}}) }
    let!(:b_param_migrated) { FactoryBot.create(:b_param, params: target_params) }
    let(:target_params) { {bike: {owner_email: "s@t.com", cycle_type: "bike"}} }
    before { b_param.update_column :params_jsonb, nil }

    it "enqueues the expected updates and updates the b_param" do
      expect(b_param_migrated.reload.params_jsonb).to eq target_params.as_json
      instance.perform
      expect(described_class).to have_enqueued_sidekiq_job(b_param.id)

      described_class.drain
      expect(b_param.reload.params_jsonb).to match_hash_indifferently target_params
    end
  end
end
