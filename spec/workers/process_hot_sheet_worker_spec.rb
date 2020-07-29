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
    let(:hot_sheet_configuration) { FactoryBot.create(:hot_sheet_configuration, is_on: true) }
    let!(:organization1) { hot_sheet_configuration.organization }
    let!(:organization2) { FactoryBot.create(:organization_with_paid_features, enabled_feature_slugs: ["hot_sheet"]) }

    before do
      Sidekiq::Worker.clear_all
      ActionMailer::Base.deliveries = []
      expect(instance.organizations.pluck(:id)).to eq([organization1.id])
      expect {
        expect(instance.perform)
      }.to change(ProcessHotSheetWorker.jobs, :count).by 1
      expect(HotSheet.count).to eq 0
      expect(ProcessHotSheetWorker.jobs.count).to eq 1
      expect(ProcessHotSheetWorker.jobs.map { |j| j["args"] }.flatten).to eq([organization1.id])
    end

    it "does not send an email" do
      expect {
        ProcessHotSheetWorker.drain
      }.to change(HotSheet, :count).by 1
      hot_sheet = HotSheet.last
      expect(hot_sheet.sheet_date).to eq Time.current.to_date
      expect(hot_sheet.organization_id).to eq organization1.id
      expect(hot_sheet.email_success?).to be_truthy
      # And it hasn't delivered any email
      expect(hot_sheet.recipient_ids).to eq([])
      expect(ActionMailer::Base.deliveries).to eq([])
    end

    context "with recipients" do
      let!(:membership) { FactoryBot.create(:membership_claimed, organization: organization1, hot_sheet_notification: "notification_daily") }
      let!(:membership_unclaimed) { FactoryBot.create(:membership, organization: organization1, hot_sheet_notification: "notification_daily") }
      it "delivers the email" do
        expect {
          ProcessHotSheetWorker.drain
        }.to change(HotSheet, :count).by 1
        hot_sheet = HotSheet.last
        expect(hot_sheet.sheet_date).to eq Time.current.to_date
        expect(hot_sheet.organization_id).to eq organization1.id
        # And it's delivered the email
        expect(hot_sheet.email_success?).to be_truthy
        expect(hot_sheet.recipient_ids).to eq([membership.user_id])
        expect(ActionMailer::Base.deliveries.count).to eq 1
        email = ActionMailer::Base.deliveries.last
        expect(email.subject).to eq hot_sheet.subject
        expect(email.to).to eq([membership.user.email])
        expect(email.bcc).to eq([])
      end
    end
  end
end
