require "rails_helper"

RSpec.describe MergeAdditionalEmailWorker, type: :job do
  let(:subject) { MergeAdditionalEmailWorker }

  it "is the correct queue" do
    expect(subject.sidekiq_options["queue"]).to eq "high_priority"
  end

  context "confirmed" do
    let(:email) { "FOO@barexample.com" }
    let(:ownership) { FactoryBot.create(:ownership, owner_email: email) }
    let(:user_email) { FactoryBot.create(:user_email, email: email) }
    let(:user) { user_email.user }
    let(:membership) { FactoryBot.create(:membership, invited_email: "#{email.upcase} ") }

    context "existing user account" do
      let(:bike) { FactoryBot.create(:bike, creator_id: old_user.id) }
      let(:old_user) { FactoryBot.create(:user_confirmed, email: email) }
      let(:pre_created_ownership) { FactoryBot.create(:ownership, creator_id: old_user.id) }
      let(:old_user_ownership) { FactoryBot.create(:ownership, owner_email: email) }
      let(:theft_alert) { FactoryBot.create(:theft_alert, user: old_user) }

      let(:organization) { membership.organization }
      let(:membership) { FactoryBot.create(:membership_claimed, user: old_user) }
      let(:second_organization) { FactoryBot.create(:organization, auto_user_id: old_user.id) }
      let(:second_membership) { FactoryBot.create(:membership_claimed, user: old_user, organization: second_organization) }
      let(:third_organization) { FactoryBot.create(:organization, auto_user_id: old_user.id) }
      let(:old_membership) { FactoryBot.create(:membership_claimed, user: old_user, organization: third_organization) }
      let(:new_membership) { FactoryBot.create(:membership_claimed, user: user, organization: third_organization) }

      let(:integration) { FactoryBot.create(:integration, user: old_user, information: {"info" => {"email" => email, :name => "blargh"}}) }
      let(:lock) { FactoryBot.create(:lock, user: old_user) }
      let(:payment) { FactoryBot.create(:payment, user: old_user) }
      let(:user_phone) { FactoryBot.create(:user_phone, user: old_user) }
      let(:customer_contact) { FactoryBot.create(:customer_contact, user: old_user, creator: old_user) }
      let(:stolen_notification) { FactoryBot.create(:stolen_notification, sender: old_user, receiver: old_user) }
      let(:oauth_application) { Doorkeeper::Application.create(name: "MyApp", redirect_uri: "https://app.com") }
      before do
        old_user.reload
        expect(ownership).to be_present
        expect(membership).to be_present
        expect(second_membership).to be_present
        expect(user_email.confirmed?).to be_truthy
        old_user_ownership.mark_claimed
        expect(old_user.reload.ownerships.pluck(:id)).to eq([ownership.id, old_user_ownership.id])
        expect(membership.user).to eq old_user
        expect(old_membership.user).to eq old_user
        expect(new_membership.user).to eq user
        expect(old_user.organizations.include?(second_organization)).to be_truthy
        expect(old_user.organizations.include?(organization)).to be_truthy
        oauth_application.update_attribute :owner_id, old_user.id
        expect(pre_created_ownership).to be_present
        expect(bike).to be_present
        expect(integration).to be_present
        expect(lock).to be_present
        expect(payment).to be_present
        expect(customer_contact).to be_present
        expect(stolen_notification).to be_present
        expect(theft_alert).to be_present
        expect(user_phone.user_id).to eq old_user.id
      end

      def expect_merged_bikes_and_memberships(ownerships_count: 2)
        user.reload
        expect(user.memberships.count).to eq 1
        expect(user.ownerships.count).to eq 0
        MergeAdditionalEmailWorker.new.perform(user_email.id)
        user.reload
        user_email.reload
        ownership.reload
        membership.reload
        second_organization.reload
        pre_created_ownership.reload
        old_user_ownership.reload
        integration.reload
        lock.reload
        payment.reload
        customer_contact.reload
        stolen_notification.reload
        bike.reload
        new_membership.reload
        expect(user_email.old_user_id).to eq old_user.id
        expect(User.where(id: old_user.id)).to_not be_present # Deleted user
        expect(Membership.where(id: old_membership.id)).to_not be_present # Deleted extra memberships

        expect(user_email.user).to eq user
        expect(user.ownerships.count).to eq ownerships_count
        expect(user.memberships.count).to eq 3
        expect(user.organizations.pluck(:id)).to match_array([organization.id, second_organization.id, third_organization.id])
        expect(membership.user).to eq user
        expect(new_membership.user).to eq user
        expect(second_organization.auto_user).to eq user
        expect(ownership.user).to eq user
        expect(old_user_ownership.user).to eq user
        expect(integration.user_id).to eq user.id
        expect(lock.user).to eq user
        expect(payment.user).to eq user
        expect(customer_contact.user).to eq user
        expect(customer_contact.creator).to eq user
        expect(stolen_notification.sender).to eq user
        expect(stolen_notification.receiver).to eq user
        expect(Doorkeeper::Application.where(owner_id: user.id).count).to eq 1
        expect(bike.creator).to eq user
        expect(pre_created_ownership.creator_id).to eq user.id
        expect(user_phone.reload.user_id).to eq user.id
      end

      it "merges bikes and memberships and deletes user" do
        expect_merged_bikes_and_memberships
      end
      context "banned user" do
        let(:old_user) { FactoryBot.create(:user_confirmed, email: email, banned: true) }
        it "merges and marks banned" do
          expect_merged_bikes_and_memberships
          expect(user.banned?).to be_truthy
        end
      end
      context "graduated_notifications, parking_notifications, stickers" do
        let(:graduated_notification) { FactoryBot.create(:graduated_notification, :with_user, user: old_user) }
        let!(:parking_notification) { FactoryBot.create(:parking_notification_organized, organization: organization, user: old_user) }
        let(:bike_sticker) { FactoryBot.create(:bike_sticker) }
        it "merges" do
          expect(graduated_notification.reload.user_id).to eq old_user.id
          expect(ParkingNotification.where(user_id: old_user.id).pluck(:id)).to eq([parking_notification.id])
          bike_sticker.claim(user: old_user, bike: bike)
          expect(bike_sticker.reload.user_id).to eq old_user.id
          expect(bike_sticker.bike_sticker_updates.pluck(:user_id)).to eq([old_user.id]) # One update, from claiming
          expect_merged_bikes_and_memberships(ownerships_count: 3)
          expect(ParkingNotification.where(user_id: user.id).pluck(:id)).to eq([parking_notification.id])
          expect(GraduatedNotification.where(user_id: user.id).pluck(:id)).to eq([graduated_notification.id])
          expect(bike_sticker.reload.user_id).to eq user.id
          expect(bike_sticker.bike_sticker_updates.pluck(:user_id)).to eq([user.id]) # One update, from claiming
        end
      end
    end

    context "existing multi-user-account" do
      it "merges all the accounts. It does not create multiple memberships for one org"
      # It would be nice to test this... future todo
    end

    context "no existing user account" do
      before do
        expect(ownership).to be_present
        expect(membership).to be_present
        expect(user_email.confirmed?).to be_truthy
      end

      it "runs the same things as user_create" do
        user.reload
        expect(user.memberships.count).to eq 0
        expect(user.ownerships.count).to eq 0
        MergeAdditionalEmailWorker.new.perform(user_email.id)
        user.reload
        user_email.reload
        ownership.reload
        expect(user_email.old_user_id).to be_nil
        expect(user.ownerships.count).to eq 1
        expect(user.memberships.count).to eq 1
        expect(ownership.user).to eq user
      end
    end
  end

  context "unconfirmed" do
    it "doesn't merge" do
      ownership = FactoryBot.create(:ownership)
      user_email = FactoryBot.create(:user_email, email: ownership.owner_email, confirmation_token: "token-stuff")
      expect(user_email.confirmed?).to be_falsey
      MergeAdditionalEmailWorker.new.perform(user_email.id)
      user_email.reload
      ownership.reload
      expect(user_email.confirmed?).to be_falsey
      expect(ownership.owner).to_not eq user_email.user
    end
  end
end
