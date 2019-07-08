require "rails_helper"

RSpec.describe ProcessMembershipWorker, type: :job do
  before { ActionMailer::Base.deliveries = [] }
  describe "#perform" do
    context "ambassador" do
      context "given a non-ambassador" do
        it "does not create ambassador_task_assignments" do
          membership = FactoryBot.create(:membership_claimed)
          FactoryBot.create(:ambassador_task)
          expect do
            described_class.new.perform(membership.id)
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
            described_class.new.perform(membership.id)
          end.to change(AmbassadorTaskAssignment, :count).by 3

          found_task_ids = user.ambassador_task_assignments.pluck(:ambassador_task_id)
          expect(found_task_ids).to match_array(task_ids)

          expect do
            described_class.new.perform(membership.id)
          end.to_not change(AmbassadorTaskAssignment, :count)

          found_task_ids = user.ambassador_task_assignments.pluck(:ambassador_task_id)
          expect(found_task_ids).to match_array(task_ids)
        end
      end
    end


    context "email not sent" do
      let(:membership) { FactoryBot.create(:membership) }
      it "sends the email" do
        expect(membership.claimed?).to be_falsey
        expect(membership.email_invitation_sent_at).to be_blank
        described_class.new.perform(membership.id)
        membership.reload
        expect(membership.claimed?).to be_falsey
        expect(membership.email_invitation_sent_at).to be_present
        expect(ActionMailer::Base.deliveries.empty?).to be_falsey
      end
      context "user with email exists" do
        let!(:user) { FactoryBot.build(:user_confirmed, email: membership.invited_email) }
        it "sends the email, claims, etc - happens automatically on save" do
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
