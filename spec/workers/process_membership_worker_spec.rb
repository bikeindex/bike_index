require "rails_helper"

RSpec.describe ProcessMembershipWorker, type: :job do
  let(:instance) { described_class.new }
  before { ActionMailer::Base.deliveries = [] }

  describe "#perform" do
    context "ambassador" do
      context "given a non-ambassador" do
        it "does not create ambassador_task_assignments" do
          membership = FactoryBot.create(:membership_claimed)
          FactoryBot.create(:ambassador_task)
          expect do
            instance.perform(membership.id)
          end.to_not change(AmbassadorTaskAssignment, :count)
          expect(ActionMailer::Base.deliveries.empty?).to be_truthy
        end
      end

      context "given an ambassador" do
        it "idempotently creates all assignments for the given ambassador" do
          task_ids = FactoryBot.create_list(:ambassador_task, 3).map(&:id)
          user = FactoryBot.create(:user_confirmed)
          membership = FactoryBot.create(:membership_ambassador, user_id: user.id)

          expect do
            instance.perform(membership.id)
          end.to change(AmbassadorTaskAssignment, :count).by 3

          found_task_ids = user.ambassador_task_assignments.pluck(:ambassador_task_id)
          expect(found_task_ids).to match_array(task_ids)

          expect do
            instance.perform(membership.id)
          end.to_not change(AmbassadorTaskAssignment, :count)

          found_task_ids = user.ambassador_task_assignments.pluck(:ambassador_task_id)
          expect(found_task_ids).to match_array(task_ids)
        end
      end
    end

    context "duplication" do
      let(:user) { FactoryBot.create(:user, email: "party@monster.com") }
      let!(:existing_membership) { FactoryBot.create(:membership, user: user) }
      let!(:membership) { FactoryBot.create(:membership, user: nil, invited_email: invitation_email, organization: existing_membership.organization) }
      let(:invitation_email) { "party@monster.com" }
      it "deletes itself" do
        expect(membership.valid?).to be_truthy
        expect(user.confirmed?).to be_falsey
        expect do
          instance.perform(membership.id)
        end.to change(Membership, :count).by(-1)
        existing_membership.reload
        expect(existing_membership).to be_present
      end
      context "confirmed user" do
        let(:user) { FactoryBot.create(:user_confirmed, email: "party@monster.com") }
        it "deletes itself" do
          expect(user.confirmed?).to be_truthy
          expect do
            instance.perform(membership.id)
          end.to change(Membership, :count).by(-1)
          existing_membership.reload
          expect(existing_membership).to be_present
        end
      end
      context "secondary email" do
        let(:invitation_email) { "not@party.com" }
        let!(:user_email) { FactoryBot.create(:user_email, user: user, email: invitation_email) }
        it "deletes itself" do
          expect do
            instance.perform(membership.id)
          end.to change(Membership, :count).by(-1)
          existing_membership.reload
          expect(existing_membership).to be_present
        end
      end
    end

    context "organization passwordless_users" do
      let(:email) { "rock@hardplace.com" }
      let(:organization) { FactoryBot.create(:organization) }
      let!(:membership) { FactoryBot.create(:membership, organization: organization, invited_email: email) }
      before { organization.update_attribute :paid_feature_slugs, ["passwordless_users"] }
      it "creates a user, does not send an email" do
        Sidekiq::Worker.clear_all
        expect do
          instance.perform(membership.id)
        end.to change(User, :count).by 1
        user = User.reorder(:created_at).last
        expect(user.memberships).to eq([membership])
        expect(user.email).to eq email
        expect(user.confirmed?).to be_truthy
        expect(EmailWelcomeWorker.jobs.count).to eq 0
        expect(EmailConfirmationWorker.jobs.count).to eq 0
        # We don't want to send users emails for organizations with passwordless users
        expect(ActionMailer::Base.deliveries.empty?).to be_truthy
      end
      context "user already exists" do
        let!(:user) { FactoryBot.create(:user, email: email) }
        it "does not create a user, send and email" do
          expect do
            instance.perform(membership.id)
          end.to_not change(User, :count)
          expect(ActionMailer::Base.deliveries.empty?).to be_falsey
        end
      end
    end

    context "email not sent" do
      let(:membership) { FactoryBot.create(:membership) }
      it "sends the email" do
        expect(membership.claimed?).to be_falsey
        expect(membership.email_invitation_sent_at).to be_blank
        expect do
          instance.perform(membership.id)
        end.to_not change(User, :count)
        membership.reload
        expect(membership.claimed?).to be_falsey
        expect(membership.email_invitation_sent_at).to be_present
        expect(ActionMailer::Base.deliveries.empty?).to be_falsey
      end
      context "user with email exists" do
        let!(:user) { FactoryBot.build(:user_confirmed, email: membership.invited_email) }
        it "does not send the email, claims, etc - happens automatically on save" do
          expect(user.memberships.count).to eq 0
          expect(membership.claimed?).to be_falsey
          expect(membership.email_invitation_sent_at).to be_blank
          user.save
          user.perform_create_jobs # TODO: Rails 5 update - this is an after_commit issue
          user.reload
          membership.reload
          expect(membership.send_invitation_email?).to be_falsey
          expect(membership.user).to eq user
          expect(membership.claimed?).to be_truthy
          expect(ActionMailer::Base.deliveries.empty?).to be_falsey
          user.reload
          expect(user.memberships.count).to eq 1
        end
      end
    end
  end
end
