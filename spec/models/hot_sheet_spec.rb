require "rails_helper"

RSpec.describe HotSheet, type: :model do
  describe "factory" do
    let(:hot_sheet) { FactoryBot.build(:hot_sheet, sheet_date: "2020-06-07") }
    let(:organization) { hot_sheet.organization }
    it "is valid" do
      hot_sheet.save
      expect(hot_sheet.valid?).to be_truthy
      expect(hot_sheet.id).to be_present
      expect(hot_sheet.email_success?).to be_falsey
      expect(HotSheet.for(organization, Date.parse("2020-06-07"))).to eq hot_sheet
      expect(hot_sheet.subject).to eq "Stolen Bike Hot Sheet: Sunday, Jun 7"
      expect(hot_sheet.previous_sheet).to be_blank
      expect(hot_sheet.next_sheet).to be_blank
    end
  end

  describe "track_email_delivery" do
    let(:hot_sheet) { FactoryBot.create(:hot_sheet) }

    it "records the success, and doesn't deliver a second time" do
      expect(hot_sheet.reload.delivery_status).to eq "delivery_pending"
      expect(hot_sheet.email_success?).to be_falsey
      deliveries = 0
      hot_sheet.track_email_delivery { deliveries += 1 }
      expect(hot_sheet.reload.delivery_status).to eq "delivery_success"
      expect(hot_sheet.delivery_error).to be_nil
      expect(hot_sheet.email_success?).to be_truthy

      hot_sheet.track_email_delivery { deliveries += 1 }
      expect(deliveries).to eq 1
    end

    context "with an unknown postmark error" do
      let(:api_error) { Postmark::ApiInputError.build("error", {"ErrorCode" => 499}) }
      it "records the failure and raises" do
        expect { hot_sheet.track_email_delivery { raise api_error } }
          .to raise_error(Postmark::ApiInputError)
        expect(hot_sheet.reload.delivery_status).to eq "delivery_failure"
        expect(hot_sheet.delivery_error).to eq "Postmark::ApiInputError"
        expect(hot_sheet.email_success?).to be_falsey
      end
    end

    context "with an undeliverable error" do
      let(:invalid_email_error) { Postmark::ApiInputError.build("error", {"ErrorCode" => 300}) }
      it "records the failure without raising" do
        hot_sheet.track_email_delivery { raise invalid_email_error }
        expect(hot_sheet.reload.delivery_status).to eq "delivery_failure"
        expect(hot_sheet.delivery_error).to eq "Postmark::InvalidEmailRequestError"
        # There is no way to tell which of the batch failed, so nobody is flagged
        expect(UserEmail.last_email_errored.count).to eq 0
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
        hot_sheet.track_email_delivery { raise inactive_recipient_error }

        # Postmark delivered to the rest of the batch, so this isn't a total failure
        expect(hot_sheet.reload.delivery_status).to eq "delivery_partial_success"
        expect(hot_sheet.delivery_error).to eq "Postmark::InactiveRecipientError"
        expect(hot_sheet.email_success?).to be_falsey
        expect(UserEmail.last_email_errored.pluck(:email)).to eq(inactive_emails)
      end

      context "with every recipient inactive" do
        let(:inactive_emails) { users.map(&:email) }
        it "records a failure, and flags them all" do
          hot_sheet.track_email_delivery { raise inactive_recipient_error }

          expect(hot_sheet.reload.delivery_status).to eq "delivery_failure"
          expect(hot_sheet.delivery_error).to eq "Postmark::InactiveRecipientError"
          expect(UserEmail.last_email_errored.pluck(:email)).to match_array(inactive_emails)
        end
      end
    end
  end

  describe "fetch_stolen_records" do
    let!(:stolen_record) { FactoryBot.create(:stolen_record, :in_nyc) }
    let(:organization) { FactoryBot.create(:organization_with_organization_features, :in_nyc, enabled_feature_slugs: ["hot_sheet"]) }
    let(:hot_sheet_configuration) { FactoryBot.create(:hot_sheet_configuration, organization: organization, is_on: true) }
    let(:hot_sheet) { FactoryBot.create(:hot_sheet, organization: organization) }
    context "with two records" do
      let!(:stolen_record2) { FactoryBot.create(:stolen_record, :in_nyc, date_stolen: Time.current - 2.days) }
      before { expect(hot_sheet_configuration).to be_present }
      it "finds the stolen records, assigns" do
        hot_sheet.reload
        expect(hot_sheet.stolen_record_ids).to be_blank
        expect(hot_sheet.fetch_stolen_records.pluck(:id)).to eq([stolen_record.id, stolen_record2.id])
        expect(hot_sheet.stolen_record_ids).to eq([stolen_record.id, stolen_record2.id])
      end
      context "with stolen record recovered" do
        let!(:stolen_record2) { FactoryBot.create(:stolen_record_recovered, date_stolen: Time.current - 2.days) }
        it "only returns if already stored" do
          expect(hot_sheet.fetch_stolen_records.pluck(:id)).to eq([stolen_record.id])
          hot_sheet.stolen_record_ids = [stolen_record.id, stolen_record2.id]
          expect(hot_sheet.fetch_stolen_records.pluck(:id)).to eq([stolen_record.id, stolen_record2.id])
        end
      end
    end
    context "with stolen_record_ids set" do
      let(:hot_sheet) { FactoryBot.create(:hot_sheet, stolen_record_ids: [stolen_record.id]) }
      it "returns the stolen records from stolen_record_ids" do
        expect(hot_sheet.organization.search_coordinates.reject(&:blank?)).to be_blank
        expect(hot_sheet.fetch_stolen_records.pluck(:id)).to eq([stolen_record.id])
      end
      context "with bike deleted" do
        it "does not return stolen record" do
          stolen_record.bike.destroy
          expect(hot_sheet.fetch_stolen_records.pluck(:id)).to eq([])
        end
      end
    end
  end

  describe "fetch_recipients" do
    let(:organization) { FactoryBot.create(:organization_with_organization_features, :in_nyc, enabled_feature_slugs: ["hot_sheet"]) }
    let!(:organization_role) { FactoryBot.create(:organization_role_claimed, organization: organization, hot_sheet_notification: "notification_daily") }
    let!(:organization_role2) { FactoryBot.create(:organization_role_claimed, organization: organization, hot_sheet_notification: "notification_never") }
    let!(:hot_sheet_configuration) { FactoryBot.create(:hot_sheet_configuration, organization: organization) }
    let(:hot_sheet) { FactoryBot.create(:hot_sheet, organization: organization) }
    it "finds the recipients" do
      expect(organization.organization_roles.pluck(:id)).to match_array([organization_role.id, organization_role2.id])
      expect(hot_sheet.recipient_ids).to be_nil
      expect(hot_sheet.fetch_recipients.pluck(:id)).to eq([organization_role.user_id])
      hot_sheet.reload
      expect(hot_sheet.recipient_ids).to eq([organization_role.user_id])
    end
    context "with recipient_ids set" do
      let(:hot_sheet) { FactoryBot.create(:hot_sheet, organization: organization, recipient_ids: [organization_role.user_id, organization_role2.user_id]) }
      it "returns the set recipients" do
        hot_sheet.reload
        expect(hot_sheet.fetch_recipients.pluck(:id)).to match_array([organization_role.user_id, organization_role2.user_id])
      end
    end
  end

  describe "for" do
    let!(:hot_sheet1) { FactoryBot.create(:hot_sheet, sheet_date: Time.current - 2.days) }
    let(:organization) { hot_sheet1.organization }
    let!(:hot_sheet2) { FactoryBot.create(:hot_sheet, sheet_date: Time.current - 1.day, organization: organization) }
    let!(:hot_sheet3) { FactoryBot.create(:hot_sheet, sheet_date: Time.current.to_date, organization: organization) }
    it "finds for the day" do
      expect(HotSheet.for(organization, (Time.current - 2.days).to_date)).to eq hot_sheet1
      expect(HotSheet.for(organization, (Time.current - 1.days).to_date)).to eq hot_sheet2
      expect(HotSheet.for(organization, Time.current.to_date)).to eq hot_sheet3
      current_hot_sheet = HotSheet.for(organization)
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
end
