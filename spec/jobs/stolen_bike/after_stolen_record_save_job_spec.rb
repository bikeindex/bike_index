require "rails_helper"

RSpec.describe StolenBike::AfterStolenRecordSaveJob, type: :job do
  let(:subject) { StolenBike::AfterStolenRecordSaveJob }
  let(:instance) { subject.new }
  before { Sidekiq::Job.clear_all }

  context "organization_stolen_message" do
    let(:organization) { FactoryBot.create(:organization_with_organization_features, kind: "bike_shop", enabled_feature_slugs: ["organization_stolen_message"]) }
    let!(:organization_stolen_message) { OrganizationStolenMessage.where(organization_id: organization.id).first_or_create }
    let(:bike) { FactoryBot.create(:bike_organized, :with_stolen_record, creation_organization: organization) }
    let(:stolen_record) { bike.reload.current_stolen_record }
    let(:ownership) { bike.ownerships.first }
    before { organization_stolen_message.update(is_enabled: true, kind: "association", body: "Alert numbers! 222") }
    it "includes organization_stolen_message" do
      expect(stolen_record.organization_stolen_message_id).to be_blank
      expect(organization_stolen_message.reload.kind).to eq "association"
      expect(organization_stolen_message.id).to be_present
      expect(organization_stolen_message.is_enabled).to be_truthy
      expect(OrganizationStolenMessage.for_stolen_record(stolen_record)&.id).to eq organization_stolen_message.id
      instance.perform(stolen_record.id)
      expect(stolen_record.reload.organization_stolen_message_id).to eq organization_stolen_message.id
      ActionMailer::Base.deliveries = []
      expect {
        Email::OwnershipInvitationJob.new.perform(ownership.id)
        Email::OwnershipInvitationJob.new.perform(ownership.id)
      }.to change(Notification, :count).by(1)
      expect(ActionMailer::Base.deliveries.count).to eq 1
      ownership.reload
      expect(ownership.notifications.count).to eq 1
      mail = ActionMailer::Base.deliveries.last
      expect(mail.body.encoded).to match "Alert numbers! 222"
    end
    context "hidden bike" do
      it "updates" do
        bike.update(marked_user_hidden: true)
        expect(bike.reload.user_hidden).to be_truthy
        expect(Bike.pluck(:id)).to eq([])
        expect(OrganizationStolenMessage.for_stolen_record(stolen_record)&.id).to eq organization_stolen_message.id
        instance.perform(stolen_record.id)
        expect(stolen_record.reload.organization_stolen_message_id).to eq organization_stolen_message.id
      end
    end
  end
end
