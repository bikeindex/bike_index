require "rails_helper"

RSpec.describe ProcessMembershipWorker, type: :job do
  describe "#perform" do
    context "ambassador" do
      context "given a non-ambassador" do
        it "does not create ambassador_task_assignments" do
          membership = FactoryBot.create(:membership_claimed)
          FactoryBot.create(:ambassador_task)
          expect do
            described_class.new.perform(membership.id)
          end.to_not change(AmbassadorTaskAssignment, :count)
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


    context "no user no email" do
      let(:membership) { FactoryBot.create(:membership) }
      it "sends the email" do

      end
    end
  end
end
