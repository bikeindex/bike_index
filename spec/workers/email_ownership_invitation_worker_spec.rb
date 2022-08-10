require "rails_helper"

RSpec.describe EmailOwnershipInvitationWorker, type: :job do
  let(:bike) { FactoryBot.create(:bike, :with_ownership) }
  let(:ownership) { bike.ownerships.first }
  it "sends an email" do
    expect(ownership.reload.notifications.count).to eq 0
    expect(ownership.user).to be_blank
    ActionMailer::Base.deliveries = []
    expect {
      EmailOwnershipInvitationWorker.new.perform(ownership.id)
      EmailOwnershipInvitationWorker.new.perform(ownership.id)
      EmailOwnershipInvitationWorker.new.perform(ownership.id)
    }.to change(Notification, :count).by(1)
    expect(ActionMailer::Base.deliveries.count).to eq 1
    expect(ownership.reload.notifications.count).to eq 1
    notification = Notification.last
    expect(notification.kind).to eq "finished_registration"
    expect(notification.delivery_status).to eq "email_success"
    expect(notification.notifiable).to eq ownership
    expect(notification.bike_id).to eq bike.id
    expect(notification.user_id).to be_blank
  end
  context "notification already exists" do
    let!(:notification) { FactoryBot.create(:notification, notifiable: ownership, kind: "finished_registration", delivery_status: delivery_status) }
    let(:delivery_status) { "email_success" }
    it "does not send an email" do
      expect(ownership.reload.notifications.count).to eq 1
      ActionMailer::Base.deliveries = []
      expect {
        EmailOwnershipInvitationWorker.new.perform(ownership.id)
        EmailOwnershipInvitationWorker.new.perform(ownership.id)
      }.to change(Notification, :count).by(0)
      expect(ActionMailer::Base.deliveries.count).to eq 0
      expect(ownership.reload.notifications.pluck(:id)).to eq([notification.id])
    end
    context "delivery_status nil" do
      let(:delivery_status) { nil }
      it "sends an email" do
        expect(ownership.reload.notifications.count).to eq 1
        ActionMailer::Base.deliveries = []
        expect {
          EmailOwnershipInvitationWorker.new.perform(ownership.id)
          EmailOwnershipInvitationWorker.new.perform(ownership.id)
        }.to change(Notification, :count).by(0)
        expect(ActionMailer::Base.deliveries.count).to eq 1
        expect(ownership.reload.notifications.pluck(:id)).to eq([notification.id])
        expect(notification.reload.delivery_status).to eq "email_success"
      end
    end
  end
  context "ownership does not exist" do
    it "does not send an email" do
      ActionMailer::Base.deliveries = []
      expect {
        EmailOwnershipInvitationWorker.new.perform(129291912)
      }.to change(Notification, :count).by(0)
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end
  context "ownership is for an example bike" do
    let(:bike) { FactoryBot.create(:bike, example: true) }
    let(:ownership) { FactoryBot.create(:ownership, bike: bike) }
    it "does not send, updates ownership to be send_email false" do
      ownership.reload
      expect(ownership.send_email).to be_truthy
      ActionMailer::Base.deliveries = []
      EmailOwnershipInvitationWorker.new.perform(ownership.id)
      expect(ActionMailer::Base.deliveries).to be_empty
      ownership.reload
      expect(ownership.calculated_send_email).to be_falsey
    end
  end
  context "creation organization has skip_email" do
    let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["skip_ownership_email"]) }
    let(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization) }
    let(:ownership) { bike.ownerships.first }
    it "doesn't send email, updates to be send_email false, sends email to the second ownership" do
      ActionMailer::Base.deliveries = []
      expect(ownership.send_email).to be_truthy
      expect {
        EmailOwnershipInvitationWorker.new.perform(ownership.id)
      }.to change(Notification, :count).by(0)
      expect(ActionMailer::Base.deliveries).to be_empty
      ownership.reload
      expect(ownership.send_email).to be_falsey
      expect(ownership.current?).to be_truthy
      # Second email
      ownership2 = FactoryBot.create(:ownership, bike: bike, created_at: Time.current)
      ownership.reload
      expect(ownership.current?).to be_falsey
      expect(ownership2.send_email).to be_truthy
      expect(ownership2.organization).to be_blank
      expect(ownership2.calculated_send_email).to be_truthy
      ActionMailer::Base.deliveries = []
      EmailOwnershipInvitationWorker.new.perform(ownership2.id)
      expect(ActionMailer::Base.deliveries.count).to eq 1
    end
  end

  context "organization_stolen_message" do
    let(:organization) { FactoryBot.create(:organization_with_organization_features, kind: "bike_shop", enabled_feature_slugs: ["organization_stolen_message"]) }
    let!(:organization_stolen_message) { OrganizationStolenMessage.where(organization_id: organization.id).first_or_create }
    let(:bike) { FactoryBot.create(:bike_organized, :with_stolen_record, creation_organization: organization) }
    let(:stolen_record) { bike.reload.current_stolen_record }
    before { organization_stolen_message.update(is_enabled: true, kind: "association", body: "Alert numbers! 222") }
    it "includes organization_stolen_message" do
      expect(stolen_record.organization_stolen_message_id).to be_blank
      expect(organization_stolen_message.reload.kind).to eq "association"
      expect(organization_stolen_message.id).to be_present
      expect(organization_stolen_message.is_enabled).to be_truthy
      expect(OrganizationStolenMessage.for_stolen_record(stolen_record)&.id).to eq organization_stolen_message.id
      ActionMailer::Base.deliveries = []
      expect {
        EmailOwnershipInvitationWorker.new.perform(ownership.id)
        EmailOwnershipInvitationWorker.new.perform(ownership.id)
      }.to change(Notification, :count).by(1)
      expect(ActionMailer::Base.deliveries.count).to eq 1
      ownership.reload
      expect(ownership.notifications.count).to eq 1
      expect(stolen_record.reload.organization_stolen_message_id).to eq organization_stolen_message.id
      mail = ActionMailer::Base.deliveries.last
      expect(mail.body.encoded).to match "Alert numbers! 222"
    end
  end
end
