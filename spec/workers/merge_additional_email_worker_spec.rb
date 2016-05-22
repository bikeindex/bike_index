require 'spec_helper'

describe MergeAdditionalEmailWorker do
  it { is_expected.to be_processed_in :updates }

  context 'confirmed' do
    let(:email) { 'foo@barexample.com' }
    let(:ownership) { FactoryGirl.create(:ownership, owner_email: email) }
    let(:user_email) { FactoryGirl.create(:user_email, email: email) }
    let(:user) { user_email.user }
    let(:organization_invitation) { FactoryGirl.create(:organization_invitation, invitee_email: "#{email.upcase} ") }

    context 'existing user account' do
      let(:bike) { FactoryGirl.create(:bike, creator_id: old_user.id) }
      let(:old_user) { FactoryGirl.create(:confirmed_user, email: email) }
      let(:pre_created_ownership) { FactoryGirl.create(:ownership, creator_id: old_user.id) }
      let(:old_user_ownership) { FactoryGirl.create(:ownership, owner_email: email) }

      let(:organization) { organization_invitation.organization }
      let(:second_organization) { FactoryGirl.create(:organization, auto_user_id: old_user.id) }
      let(:membership) { FactoryGirl.create(:membership, user: old_user, organization: second_organization) }
      let(:third_organization) { FactoryGirl.create(:organization, auto_user_id: old_user.id) }
      let(:old_membership) { FactoryGirl.create(:membership, user: old_user, organization: third_organization) }
      let(:new_membership) { FactoryGirl.create(:membership, user: user, organization: third_organization) }

      let(:integration) { FactoryGirl.create(:integration, user: old_user, information: { 'info' => { 'email' => email, name: 'blargh' } }) }
      let(:lock) { FactoryGirl.create(:lock, user: old_user) }
      let(:payment) { FactoryGirl.create(:payment, user: old_user) }
      let(:customer_contact) { FactoryGirl.create(:customer_contact, user: old_user, creator: old_user) }
      let(:stolen_notification) { FactoryGirl.create(:stolen_notification, sender: old_user, receiver: old_user) }
      let(:oauth_application) { Doorkeeper::Application.create(name: 'MyApp', redirect_uri: 'https://app.com') }
      before do
        old_user.reload
        expect(ownership).to be_present
        expect(organization_invitation).to be_present
        expect(user_email.confirmed).to be_truthy
        old_user_ownership.mark_claimed
        expect(old_user.ownerships.first).to eq old_user_ownership
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
      end

      it 'merges bikes and memberships and deletes user' do
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

        expect(user.ownerships.count).to eq 2
        expect(user.memberships.count).to eq 3
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
      end
    end

    context 'existing multi-user-account' do
      it 'merges all the accounts. It does not create multiple memberships for one org'
      # It would be nice to test this... future todo
    end

    context 'no existing user account' do
      before do
        expect(ownership).to be_present
        expect(organization_invitation).to be_present
        expect(user_email.confirmed).to be_truthy
      end

      it 'runs the same things as user_create' do
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

  context 'unconfirmed' do
    it "doesn't merge" do
      ownership = FactoryGirl.create(:ownership)
      user_email = FactoryGirl.create(:user_email, email: ownership.owner_email, confirmation_token: 'token-stuff')
      expect(user_email.confirmed).to be_falsey
      MergeAdditionalEmailWorker.new.perform(user_email.id)
      user_email.reload
      ownership.reload
      expect(user_email.confirmed).to be_falsey
      expect(ownership.owner).to_not eq user_email.user
    end
  end
end
