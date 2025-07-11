require "rails_helper"

RSpec.describe Users::ProcessOrganizationRoleJob, type: :job do
  let(:instance) { described_class.new }
  before { ActionMailer::Base.deliveries = [] }

  describe "#perform" do
    context "ambassador" do
      context "given a non-ambassador" do
        it "does not create ambassador_task_assignments" do
          organization_role = FactoryBot.create(:organization_role_claimed)
          FactoryBot.create(:ambassador_task)
          expect {
            instance.perform(organization_role.id)
          }.to_not change(AmbassadorTaskAssignment, :count)
          expect(ActionMailer::Base.deliveries.empty?).to be_truthy
        end
      end

      context "given an ambassador" do
        it "idempotently creates all assignments for the given ambassador" do
          task_ids = FactoryBot.create_list(:ambassador_task, 3).map(&:id)
          user = FactoryBot.create(:user_confirmed)
          organization_role = FactoryBot.create(:organization_role_ambassador, user_id: user.id)

          expect {
            instance.perform(organization_role.id)
          }.to change(AmbassadorTaskAssignment, :count).by 3

          found_task_ids = user.ambassador_task_assignments.pluck(:ambassador_task_id)
          expect(found_task_ids).to match_array(task_ids)

          expect {
            instance.perform(organization_role.id)
          }.to_not change(AmbassadorTaskAssignment, :count)

          found_task_ids = user.ambassador_task_assignments.pluck(:ambassador_task_id)
          expect(found_task_ids).to match_array(task_ids)
        end
      end
    end

    context "duplication" do
      let(:user) { FactoryBot.create(:user, email: "party@monster.com") }
      let!(:existing_organization_role) { FactoryBot.create(:organization_role, user: user) }
      let!(:organization_role) { FactoryBot.create(:organization_role, user: nil, invited_email: invitation_email, organization: existing_organization_role.organization) }
      let(:invitation_email) { "party@monster.com" }
      it "deletes itself" do
        expect(organization_role.valid?).to be_truthy
        expect(user.confirmed?).to be_falsey
        expect {
          instance.perform(organization_role.id)
        }.to change(OrganizationRole, :count).by(-1)
        existing_organization_role.reload
        expect(existing_organization_role).to be_present
      end
      context "confirmed user" do
        let(:user) { FactoryBot.create(:user_confirmed, email: "party@monster.com") }
        it "deletes itself" do
          expect(user.confirmed?).to be_truthy
          expect {
            instance.perform(organization_role.id)
          }.to change(OrganizationRole, :count).by(-1)
          existing_organization_role.reload
          expect(existing_organization_role).to be_present
        end
      end
      context "secondary email" do
        let(:invitation_email) { "not@party.com" }
        let!(:user_email) { FactoryBot.create(:user_email, user: user, email: invitation_email) }
        it "deletes itself" do
          expect {
            instance.perform(organization_role.id)
          }.to change(OrganizationRole, :count).by(-1)
          existing_organization_role.reload
          expect(existing_organization_role).to be_present
        end
      end
    end

    context "organization passwordless_users" do
      let(:email) { "rock@hardplace.com" }
      let(:organization) { FactoryBot.create(:organization) }
      let!(:organization_role) { FactoryBot.create(:organization_role, organization: organization, invited_email: email) }
      before { organization.update_attribute :enabled_feature_slugs, ["passwordless_users"] }
      it "creates a user, does not send an email" do
        Sidekiq::Job.clear_all
        expect {
          instance.perform(organization_role.id)
        }.to change(User, :count).by 1
        user = User.reorder(:created_at).last
        expect(user.organization_roles).to eq([organization_role])
        expect(user.email).to eq email
        expect(user.confirmed?).to be_truthy
        expect(Email::WelcomeJob.jobs.count).to eq 0
        expect(Email::ConfirmationJob.jobs.count).to eq 0
        # We don't want to send users emails for organizations with passwordless users
        expect(ActionMailer::Base.deliveries.empty?).to be_truthy
        # There was a bug where users weren't getting the magic link token when it was sent to them. So verify that we create the token
        user.send_magic_link_email
        expect(user.magic_link_token).to be_present
      end
      context "user already exists" do
        let!(:user) { FactoryBot.create(:user, email: email) }
        it "does not create a user, send and email" do
          expect {
            instance.perform(organization_role.id)
          }.to_not change(User, :count)
          expect(ActionMailer::Base.deliveries.empty?).to be_falsey
        end
      end
    end

    context "email not sent" do
      let(:organization_role) { FactoryBot.create(:organization_role) }
      it "sends the email" do
        expect(organization_role.claimed?).to be_falsey
        expect(organization_role.email_invitation_sent_at).to be_blank
        expect {
          instance.perform(organization_role.id)
        }.to_not change(User, :count)
        organization_role.reload
        expect(organization_role.claimed?).to be_falsey
        expect(organization_role.email_invitation_sent_at).to be_present
        expect(ActionMailer::Base.deliveries.empty?).to be_falsey
      end
      context "user with email exists" do
        let!(:user) { FactoryBot.build(:user_confirmed, email: organization_role.invited_email) }
        it "does not send the email, claims, etc - happens automatically on save" do
          expect(user.organization_roles.count).to eq 0
          expect(organization_role.claimed?).to be_falsey
          expect(organization_role.email_invitation_sent_at).to be_blank
          user.save
          user.reload
          organization_role.reload
          expect(organization_role.send_invitation_email?).to be_falsey
          expect(organization_role.user).to eq user
          expect(organization_role.claimed?).to be_truthy
          expect(ActionMailer::Base.deliveries.empty?).to be_falsey
          user.reload
          expect(user.organization_roles.count).to eq 1
        end
      end
    end
  end
end
