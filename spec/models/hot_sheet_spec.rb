require "rails_helper"

RSpec.describe HotSheet, type: :model do
  describe "factory" do
    let(:hot_sheet) { FactoryBot.build(:hot_sheet, sheet_date: "2020-06-07") }
    let(:organization) { hot_sheet.organization }
    it "is valid" do
      hot_sheet.save
      expect(hot_sheet.valid?).to be_truthy
      expect(hot_sheet.id).to be_present
      expect(hot_sheet.delivery_success?).to be_falsey
      expect(HotSheet.for(organization, Date.parse("2020-06-07"))).to eq [hot_sheet]
      expect(hot_sheet.subject).to eq "Stolen Bike Hot Sheet: Sunday, Jun 7"
      expect(hot_sheet.previous_sheet).to be_blank
      expect(hot_sheet.next_sheet).to be_blank
    end
  end

  describe "track_email_delivery" do
    let(:hot_sheet) { FactoryBot.create(:hot_sheet, recipient_ids: []) }

    it "records the success, and doesn't deliver a second time" do
      expect(hot_sheet.reload.delivery_status).to eq "delivery_pending"
      expect(hot_sheet.delivery_success?).to be_falsey
      deliveries = 0
      expect(HotSheet.track_email_delivery(hot_sheet) { deliveries += 1 }).to be_nil
      expect(hot_sheet.reload.delivery_status).to eq "delivery_success"
      expect(hot_sheet.delivery_error).to be_nil
      expect(hot_sheet.delivery_success?).to be_truthy

      HotSheet.track_email_delivery(hot_sheet) { deliveries += 1 }
      expect(deliveries).to eq 1
    end

    context "with an unknown postmark error" do
      let(:api_error) { Postmark::ApiInputError.build("error", {"ErrorCode" => 499}) }
      it "records the failure and raises" do
        expect { HotSheet.track_email_delivery(hot_sheet) { raise api_error } }.to raise_error(Postmark::ApiInputError)
        expect(hot_sheet.reload.delivery_status).to eq "delivery_failure"
        expect(hot_sheet.delivery_error).to eq "Postmark::ApiInputError"
        expect(hot_sheet.delivery_success?).to be_falsey
      end
    end

    context "with an undeliverable error" do
      let(:invalid_email_error) { Postmark::ApiInputError.build("error", {"ErrorCode" => 300}) }
      it "records the failure without returning an error" do
        expect(HotSheet.track_email_delivery(hot_sheet) { raise invalid_email_error }).to be_nil
        expect(hot_sheet.reload.delivery_status).to eq "delivery_failure"
        expect(hot_sheet.delivery_error).to eq "Postmark::InvalidEmailRequestError"
        # There is no way to tell which of the batch failed, so nobody is flagged
        expect(UserEmail.last_email_errored.count).to eq 0
        expect(hot_sheet.delivery_settled?).to be_truthy
        deliveries = 0
        HotSheet.track_email_delivery(hot_sheet) { deliveries += 1 }
        expect(deliveries).to eq 0
      end
    end

    context "with banned recipients" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:users) { Array.new(2) { FactoryBot.create(:organization_role_claimed, organization:).user } }
      let(:hot_sheet) { FactoryBot.create(:hot_sheet, organization:, recipient_ids: users.map(&:id)) }
      let(:banned_users) { users }
      before { banned_users.each { FactoryBot.create(:email_ban, user: it, reason: :honeypot) } }

      it "doesn't deliver, and doesn't try again" do
        deliveries = 0
        HotSheet.track_email_delivery(hot_sheet) { deliveries += 1 }
        expect(deliveries).to eq 0
        expect(hot_sheet.reload.delivery_status).to eq "delivery_banned"
        expect(hot_sheet.delivery_settled?).to be_truthy

        HotSheet.track_email_delivery(hot_sheet) { deliveries += 1 }
        expect(deliveries).to eq 0
      end

      context "with only some banned" do
        let(:banned_users) { users.first(1) }
        it "delivers" do
          deliveries = 0
          HotSheet.track_email_delivery(hot_sheet) { deliveries += 1 }
          expect(deliveries).to eq 1
          expect(hot_sheet.reload.delivery_status).to eq "delivery_success"
        end
      end
    end

    context "with an inactive recipient" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:users) { Array.new(3) { FactoryBot.create(:organization_role_claimed, organization:).user } }
      let(:hot_sheet) { FactoryBot.create(:hot_sheet, organization:, recipient_ids: users.map(&:id)) }
      let(:inactive_emails) { [users.first.email] }
      let(:error_message) do
        "You tried to send to recipient(s) that have been marked as inactive. Found inactive addresses: " \
        "#{inactive_emails.join(", ")}. Inactive recipients are ones that have generated a hard bounce, " \
        "a spam complaint, or a manual suppression."
      end
      let(:inactive_recipient_error) do
        Postmark::ApiInputError.build("error", {"ErrorCode" => 406, "Message" => error_message})
      end

      it "records a partial success, and only flags the address that was rejected" do
        expect(hot_sheet.recipient_emails).to match_array(users.map(&:email))
        expect(UserEmail.last_email_errored.count).to eq 0
        expect(HotSheet.track_email_delivery(hot_sheet) { raise inactive_recipient_error }).to be_nil

        # Postmark delivered to the rest of the batch, so this isn't a total failure
        expect(hot_sheet.reload.delivery_status).to eq "delivery_partial_success"
        expect(hot_sheet.delivery_error).to eq "Postmark::InactiveRecipientError"
        expect(hot_sheet.delivery_success?).to be_falsey
        expect(UserEmail.last_email_errored.pluck(:email)).to eq(inactive_emails)
        # ... so the batch isn't worth sending again
        expect(hot_sheet.delivery_settled?).to be_truthy
        deliveries = 0
        HotSheet.track_email_delivery(hot_sheet) { deliveries += 1 }
        expect(deliveries).to eq 0
      end

      context "with every recipient inactive" do
        let(:inactive_emails) { users.map(&:email) }
        it "records a failure, and flags them all" do
          HotSheet.track_email_delivery(hot_sheet) { raise inactive_recipient_error }

          expect(hot_sheet.reload.delivery_status).to eq "delivery_failure"
          expect(hot_sheet.delivery_error).to eq "Postmark::InactiveRecipientError"
          expect(UserEmail.last_email_errored.pluck(:email)).to match_array(inactive_emails)
        end
      end

      context "with an error postmark didn't attribute" do
        let(:error_message) { "You tried to send to recipient(s) that have been marked as inactive." }
        it "records a partial success, without flagging anyone" do
          expect(inactive_recipient_error.recipients).to eq([])
          expect(HotSheet.track_email_delivery(hot_sheet) { raise inactive_recipient_error }).to be_nil

          expect(hot_sheet.reload.delivery_status).to eq "delivery_partial_success"
          expect(hot_sheet.delivery_error).to eq "Postmark::InactiveRecipientError"
          expect(UserEmail.last_email_errored.count).to eq 0
        end
      end
    end
  end

  describe "fetch_stolen_records" do
    let!(:stolen_record) { FactoryBot.create(:stolen_record, :in_nyc) }
    # A sheet keeps rendering a bike that's been recovered since it was built
    let!(:stolen_record_recovered) { FactoryBot.create(:stolen_record_recovered, date_stolen: Time.current - 2.days) }
    let(:hot_sheet) { FactoryBot.create(:hot_sheet, stolen_record_ids: [stolen_record.id, stolen_record_recovered.id]) }

    it "returns the sheet's stolen records" do
      expect(hot_sheet.fetch_stolen_records.pluck(:id)).to eq([stolen_record.id, stolen_record_recovered.id])
    end

    context "with bike deleted" do
      it "does not return stolen record" do
        stolen_record.bike.destroy
        expect(hot_sheet.fetch_stolen_records.pluck(:id)).to eq([stolen_record_recovered.id])
      end
    end
  end

  describe "for" do
    let!(:hot_sheet1) { FactoryBot.create(:hot_sheet, sheet_date: Time.current - 2.days) }
    let(:organization) { hot_sheet1.organization }
    let!(:hot_sheet2) { FactoryBot.create(:hot_sheet, sheet_date: Time.current - 1.day, organization: organization) }
    let!(:hot_sheet3) { FactoryBot.create(:hot_sheet, sheet_date: Time.current.to_date, organization: organization) }
    it "finds for the day" do
      expect(HotSheet.for(organization, (Time.current - 2.days).to_date)).to eq [hot_sheet1]
      expect(HotSheet.for(organization, (Time.current - 1.days).to_date)).to eq [hot_sheet2]
      expect(HotSheet.for(organization, Time.current.to_date)).to eq [hot_sheet3]
      current_hot_sheet = HotSheet.new(organization:)
      expect(current_hot_sheet.current?).to be_truthy
      expect(current_hot_sheet.next_sheet&.id).to be_blank
      expect(current_hot_sheet.previous_sheet&.id).to eq hot_sheet3.id

      expect(hot_sheet3.next_sheet&.id).to be_blank
      expect(hot_sheet3.previous_sheet&.id).to eq hot_sheet2.id

      expect(hot_sheet2.next_sheet&.id).to eq hot_sheet3.id
      expect(hot_sheet2.previous_sheet&.id).to eq hot_sheet1.id

      expect(hot_sheet1.next_sheet&.id).to eq hot_sheet2.id
      expect(hot_sheet1.previous_sheet&.id).to be_blank
    end
  end

  describe "for a day without sheets" do
    let(:organization) { FactoryBot.create(:organization_with_organization_features, :in_nyc, enabled_feature_slugs: ["hot_sheet"]) }
    let!(:hot_sheet_configuration) { FactoryBot.create(:hot_sheet_configuration, organization:) }
    let!(:organization_roles) do
      Array.new(3) { FactoryBot.create(:organization_role_claimed, organization:, hot_sheet_notification: "notification_daily") }
    end
    let!(:organization_role_never) { FactoryBot.create(:organization_role_claimed, organization:, hot_sheet_notification: "notification_never") }
    let!(:stolen_record) { FactoryBot.create(:stolen_record, :in_nyc) }
    let!(:stolen_record_recovered) { FactoryBot.create(:stolen_record_recovered, :in_nyc) }
    before { stub_const("HotSheet::RECIPIENTS_PER_EMAIL", 2) }

    it "builds a sheet for each batch of daily recipients, without saving them" do
      hot_sheets = HotSheet.for(organization, Time.current.to_date)
      expect(hot_sheets.map(&:persisted?)).to eq([false, false])
      expect(hot_sheets.map(&:sheet_date)).to eq([Time.current.to_date] * 2)
      expect(hot_sheets.map { it.recipient_ids.count }).to eq([2, 1])
      expect(hot_sheets.flat_map(&:recipient_emails)).to match_array(organization_roles.map { it.user.email })
      # Every sheet renders the same bikes, and a recovered bike isn't one of them
      expect(hot_sheets.map(&:stolen_record_ids)).to eq([[stolen_record.id]] * 2)
    end

    context "for a past day" do
      it "builds nothing" do
        expect(HotSheet.for(organization, Time.current.to_date - 1.day)).to eq([])
      end
    end

    context "without a configuration" do
      let!(:hot_sheet_configuration) { nil }
      it "builds nothing" do
        expect(HotSheet.for(organization, Time.current.to_date)).to eq([])
      end
    end

    context "with no recipients" do
      let!(:organization_roles) { [] }
      it "builds one sheet, with nobody to email" do
        expect(HotSheet.for(organization, Time.current.to_date).map(&:recipient_ids)).to eq([[]])
      end
    end
  end
end
