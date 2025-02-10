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
    let!(:organization2) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["hot_sheet"]) }

    before do
      Sidekiq::Worker.clear_all
      ActionMailer::Base.deliveries = []
      # Skip timezone concerns, it's always send time!
      allow_any_instance_of(HotSheetConfiguration).to receive(:send_today_at) { 0 }
      expect(organization1.hot_sheet_configuration.send_today_now?).to be_truthy
      expect {
        instance.perform
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
      let!(:organization_role) { FactoryBot.create(:organization_role_claimed, organization: organization1, hot_sheet_notification: "notification_daily") }
      let!(:organization_role_unclaimed) { FactoryBot.create(:organization_role, organization: organization1, hot_sheet_notification: "notification_daily") }
      it "delivers the email" do
        expect {
          ProcessHotSheetWorker.drain
        }.to change(HotSheet, :count).by 1
        hot_sheet = HotSheet.last
        expect(hot_sheet.sheet_date).to eq Time.current.to_date
        expect(hot_sheet.organization_id).to eq organization1.id
        # And it's delivered the email
        expect(hot_sheet.email_success?).to be_truthy
        expect(hot_sheet.recipient_ids).to eq([organization_role.user_id])
        expect(ActionMailer::Base.deliveries.count).to eq 1
        email = ActionMailer::Base.deliveries.last
        expect(email.subject).to eq hot_sheet.subject
        expect(email.to).to eq([organization_role.user.email])
        expect(email.bcc).to eq([])
      end
      context "with more than 50 recipients" do
        let(:emails) { Array(1..102).map { |i| "email#{i}@bikeindex.org" } }
        it "delivers multiple emails" do
          expect(ActionMailer::Base.deliveries.count).to eq 0
          allow_any_instance_of(HotSheet).to receive(:recipient_emails) { emails }
          expect {
            ProcessHotSheetWorker.drain
          }.to change(HotSheet, :count).by 1
          hot_sheet = HotSheet.last
          expect(hot_sheet.sheet_date).to eq Time.current.to_date
          expect(hot_sheet.organization_id).to eq organization1.id
          # And it's delivered the email
          expect(hot_sheet.email_success?).to be_truthy
          expect(hot_sheet.recipient_ids).to eq([organization_role.user_id])
          expect(ActionMailer::Base.deliveries.count).to eq 3

          ActionMailer::Base.deliveries.each do |email|
            expect(email.subject).to eq hot_sheet.subject
            expect(email.bcc.count).to be < 49
          end

          expect(Notification.count).to eq 102
        end
      end
    end
  end
end
