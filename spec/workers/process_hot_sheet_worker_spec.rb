require "rails_helper"

RSpec.describe ProcessHotSheetWorker, type: :lib do
  let(:instance) { described_class.new }
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority" # overrides default
    expect(described_class.frequency).to be < 55.minutes
  end

  describe "perform" do
    let(:hot_sheet_configuration) { FactoryBot.create(:hot_sheet_configuration, is_enabled: true) }
    let!(:organization1) { hot_sheet_configuration.organization }
    let!(:organization2) { FactoryBot.create(:organization_with_paid_features, enabled_feature_slugs: ["hot_sheet"]) }
    it "enqueues just enabled" do
      Sidekiq::Worker.clear_all
      expect(instance.organizations.pluck(:id)).to eq([organization1.id])
      expect do
        expect(instance.perform)
      end.to change(ProcessHotSheetWorker.jobs, :count).by 1

      expect(HotSheet.count).to eq 0
      expect(ProcessHotSheetWorker.jobs.count).to eq 1
      expect(ProcessHotSheetWorker.jobs.map { |j| j["args"] }.flatten).to eq([organization1.id])

      expect do
        ProcessHotSheetWorker.drain
      end.to change(HotSheet, :count).by 1

      hot_sheet = HotSheet.last
      expect(hot_sheet.sheet_date).to eq Time.current.to_date
      expect(hot_sheet.organization_id).to eq organization1.id
      # And it's delivered the email
      expect(hot_sheet.email_success?).to be_truthy
    end
  end
end
