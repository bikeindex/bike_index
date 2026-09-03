require "rails_helper"

RSpec.describe ProcessHotSheetJob, type: :lib do
  let(:instance) { described_class.new }
  include_context :scheduled_job
  include_examples :scheduled_job_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority" # overrides default
    expect(described_class.frequency).to be < 55.minutes
  end

  describe "perform" do
    let(:hot_sheet_configuration) { FactoryBot.create(:hot_sheet_configuration, is_on: true) }
    let!(:organization1) { hot_sheet_configuration.organization }
    let!(:organization2) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["hot_sheet"]) }

    before do
      Sidekiq::Job.clear_all
      ActionMailer::Base.deliveries = []
      # Skip timezone concerns, it's always send time!
      allow_any_instance_of(HotSheetConfiguration).to receive(:send_today_at) { 0 }
      expect(organization1.hot_sheet_configuration.send_today_now?).to be_truthy
      expect {
        instance.perform
      }.to change(ProcessHotSheetJob.jobs, :count).by 1
      expect(HotSheet.count).to eq 0
      expect(ProcessHotSheetJob.jobs.count).to eq 1
      expect(ProcessHotSheetJob.jobs.map { |j| j["args"] }.flatten).to eq([organization1.id])
    end

    it "does not send an email" do
      expect {
        ProcessHotSheetJob.drain
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
          ProcessHotSheetJob.drain
        }.to change(HotSheet, :count).by 1
        hot_sheet = HotSheet.last
        expect(hot_sheet.sheet_date).to eq Time.current.to_date
        expect(hot_sheet.organization_id).to eq organization1.id
        # And it's delivered the email
        expect(hot_sheet.email_success?).to be_truthy
        expect(hot_sheet.recipient_ids).to eq([organization_role.user_id])
        expect(ActionMailer::Base.deliveries.count).to eq 1
        email = ActionMailer::Base.deliveries.last
        expect(hot_sheet.message_id).to eq email.message_id
        expect(email.subject).to eq hot_sheet.subject
        expect(email.to).to eq([organization_role.user.email])
        expect(email.bcc).to eq([])
      end

      context "with a bike whose thumb_path has gone stale" do
        let!(:stolen_record) { FactoryBot.create(:stolen_record, :in_nyc, :with_bike_image) }
        let(:bike) { stolen_record.bike }
        before { bike.update_column(:thumb_path, nil) }

        it "refreshes it before the email renders" do
          ProcessHotSheetJob.drain
          expect(HotSheet.last.stolen_record_ids).to eq([stolen_record.id])
          expect(bike.reload.thumb_path).to be_present
          expect(ActionMailer::Base.deliveries.count).to eq 1
        end
      end
      context "with more recipients than fit in one email" do
        let!(:organization_roles) do
          Array.new(8) { FactoryBot.create(:organization_role_claimed, organization: organization1, hot_sheet_notification: "notification_daily") }
        end
        let!(:organization_role_never) { FactoryBot.create(:organization_role_claimed, organization: organization1, hot_sheet_notification: "notification_never") }
        let!(:stolen_record) { FactoryBot.create(:stolen_record, :in_nyc) }
        let(:recipient_ids) { ([organization_role] + organization_roles).map(&:user_id) }
        before { stub_const("ProcessHotSheetJob::RECIPIENTS_PER_EMAIL", 3) }

        it "creates a hot sheet for each slice of recipients, and emails each one" do
          expect(ActionMailer::Base.deliveries.count).to eq 0
          expect {
            ProcessHotSheetJob.drain
          }.to change(HotSheet, :count).by 3
          hot_sheets = HotSheet.where(sheet_date: Time.current.to_date).order(:id)
          # The sheets are identical, other than which recipients they went to
          expect(hot_sheets.map(&:organization_id)).to eq([organization1.id] * 3)
          expect(hot_sheets.map(&:stolen_record_ids)).to eq([[stolen_record.id]] * 3)
          expect(hot_sheets.map { it.recipient_ids.count }).to eq([3, 3, 3])
          # Every daily recipient is on exactly one sheet, and notification_never on none
          expect(hot_sheets.flat_map(&:recipient_ids)).to match_array(recipient_ids)

          expect(ActionMailer::Base.deliveries.count).to eq 3
          hot_sheets.each do |hot_sheet|
            email = ActionMailer::Base.deliveries.find { (it.to + it.bcc).sort == hot_sheet.recipient_emails.sort }
            expect(email).to be_present
            expect(email.subject).to eq hot_sheet.subject
          end
        end

        context "re-run after the day's batches failed" do
          it "reuses the day's sheets, rather than stacking up duplicates" do
            expect {
              ProcessHotSheetJob.drain
            }.to change(HotSheet, :count).by 3
            HotSheet.all.each { it.update(delivery_status: "delivery_failure", delivery_error: "Postmark::TimeoutError") }
            ActionMailer::Base.deliveries = []

            expect {
              described_class.new.perform(organization1.id)
            }.to_not change(HotSheet, :count)
            expect(ActionMailer::Base.deliveries.count).to eq 3
            expect(HotSheet.delivered.count).to eq 3
          end
        end
        context "when one batch has an inactive recipient" do
          let(:inactive_user) { organization_roles.first.user }
          let(:error_message) do
            "You tried to send to recipient(s) that have been marked as inactive. Found inactive " \
            "addresses: #{inactive_user.email}. Inactive recipients are ones that have generated a " \
            "hard bounce, a spam complaint, or a manual suppression."
          end
          let(:inactive_recipient_error) do
            Postmark::ApiInputError.build("error", {"ErrorCode" => 406, "Message" => error_message})
          end
          before do
            allow(OrganizedMailer).to receive(:hot_sheet).and_wrap_original do |method, sheet|
              raise inactive_recipient_error if sheet.recipient_ids.include?(inactive_user.id)

              method.call(sheet)
            end
          end

          it "delivers the batches that don't include them" do
            expect {
              ProcessHotSheetJob.drain
            }.to change(HotSheet, :count).by 3
            hot_sheets = HotSheet.where(sheet_date: Time.current.to_date)
            expect(hot_sheets.delivery_success.count).to eq 2
            expect(hot_sheets.delivery_partial_success.count).to eq 1
            expect(ActionMailer::Base.deliveries.count).to eq 2

            rejected = hot_sheets.delivery_partial_success.first
            expect(rejected.delivery_error).to eq "Postmark::InactiveRecipientError"
            expect(rejected.recipient_ids).to include(inactive_user.id)
            # Only the rejected address is flagged, not the rest of their batch
            expect(UserEmail.last_email_errored.pluck(:email)).to eq([inactive_user.email])
          end

          context "with an error postmark can't attribute" do
            let(:inactive_recipient_error) { Postmark::ApiInputError.build("error", {"ErrorCode" => 499}) }
            it "delivers the other batches before raising" do
              expect {
                ProcessHotSheetJob.drain
              }.to raise_error(Postmark::ApiInputError)
              hot_sheets = HotSheet.where(sheet_date: Time.current.to_date)
              expect(hot_sheets.count).to eq 3
              expect(hot_sheets.delivery_success.count).to eq 2
              expect(hot_sheets.delivery_failure.count).to eq 1
              expect(ActionMailer::Base.deliveries.count).to eq 2
              # Nobody is flagged - there is no telling which of the batch failed
              expect(UserEmail.last_email_errored.count).to eq 0
            end
          end
        end
      end
    end
  end
end
