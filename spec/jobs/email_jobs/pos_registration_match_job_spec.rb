require "rails_helper"

RSpec.describe EmailJobs::PosRegistrationMatchJob, type: :job do
  let(:instance) { described_class.new }
  let(:match) { FactoryBot.create(:pos_registration_match) }
  let(:user) { match.bike.user }

  before { ActionMailer::Base.deliveries = [] }

  it "emails the owner once" do
    expect {
      instance.perform(match.id)
      instance.perform(match.id)
    }.to change(Notification, :count).by 1
    expect(ActionMailer::Base.deliveries.map(&:to)).to eq([[user.email]])
    expect(Notification.last).to have_attributes(kind: "pos_registration_match", notifiable: match, user_id: user.id,
      bike_id: match.pos_bike_id, delivery_status: "delivery_success")
  end

  context "with an earlier failed email to a former owner" do
    before do
      Notification.create!(kind: "pos_registration_match", notifiable: match, user: FactoryBot.create(:user_confirmed),
        delivery_status: "delivery_failure")
    end

    it "emails the current owner" do
      instance.perform(match.id)
      expect(ActionMailer::Base.deliveries.map(&:to)).to eq([[user.email]])
    end
  end

  context "the shop registered it to another email" do
    let(:match) { FactoryBot.create(:pos_registration_match, :different_email) }

    it "emails that address once, with the token's link" do
      expect {
        instance.perform(match.id)
        instance.perform(match.id)
      }.to change(Notification, :count).by 1
      mail = ActionMailer::Base.deliveries.sole
      expect(mail.to).to eq(["shop-customer@example.com"])
      expect(mail.html_part.body.to_s).to include("/pos_registration_matches/#{match.token}")
      expect(mail.html_part.body.to_s).not_to include(user.email)
      expect(Notification.last).to have_attributes(kind: "pos_registration_match", user_id: nil,
        message_channel_target: "shop-customer@example.com", delivery_status: "delivery_success")
    end

    context "whose account asked for no email but theft alerts" do
      before do
        FactoryBot.create(:user_confirmed, email: "shop-customer@example.com", no_non_theft_notification: true)
      end

      it "doesn't send" do
        expect(match.asked_user).to be_present
        instance.perform(match.id)
        expect(ActionMailer::Base.deliveries.count).to eq 0
      end
    end
  end

  context "with a POS registration the owner hid" do
    before { match.pos_bike.update_column(:user_hidden, true) }

    it "emails" do
      instance.perform(match.id)
      expect(ActionMailer::Base.deliveries.count).to eq 1
    end
  end

  context "when it doesn't email" do
    context "while skipped" do
      before { stub_const("ENV", ENV.to_h.merge(described_class.skip_env_var => "true")) }

      it "doesn't send" do
        instance.perform(match.id)
        expect(ActionMailer::Base.deliveries.count).to eq 0
      end
    end

    context "with a theft since the match" do
      before { FactoryBot.create(:stolen_bike, serial_number: match.bike.serial_number) }

      it "records it" do
        instance.perform(match.id)
        expect(match.reload.review_reasons).to eq ["stolen_history"]
        expect(ActionMailer::Base.deliveries.count).to eq 0
      end
    end

    context "when the POS registration is someone else's" do
      before { BikeServices::OwnershipTransferer.find_or_create(match.pos_bike, updator: user, new_owner_email: "new-owner@example.com") }

      it "doesn't send" do
        instance.perform(match.id)
        expect(ActionMailer::Base.deliveries.count).to eq 0
      end
    end

    context "when the owner asked for no email but theft alerts" do
      before { user.update!(no_non_theft_notification: true) }

      it "doesn't send" do
        instance.perform(match.id)
        expect(ActionMailer::Base.deliveries.count).to eq 0
        expect(Notification.count).to eq 0
      end
    end

    # Written because the mailer raised on the deleted account's missing user
    context "when the owner's account is deleted" do
      before { user.update_column(:deleted_at, Time.current) }

      it "doesn't send" do
        expect(match.reload.bike.user_id).to be_present
        instance.perform(match.id)
        expect(ActionMailer::Base.deliveries.count).to eq 0
        expect(Notification.count).to eq 0
      end
    end

    context "with a review reason" do
      before { match.update!(review_reasons: ["impounded"]) }

      it "doesn't send" do
        instance.perform(match.id)
        expect(ActionMailer::Base.deliveries.count).to eq 0
      end
    end

    context "when the match isn't pending" do
      before { match.update!(status: :declined) }

      it "doesn't send" do
        instance.perform(match.id)
        expect(ActionMailer::Base.deliveries.count).to eq 0
      end
    end
  end
end
