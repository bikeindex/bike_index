require "rails_helper"

RSpec.describe AmbassadorMembershipAfterCreateWorker, type: :job do
  describe "#perform" do
    context "given a non-ambassador" do
      it "no-ops" do
        membership = FactoryBot.create(:existing_membership)
        allow(AmbassadorTaskAssignmentCreator)
          .to(receive(:assign_all_ambassador_tasks_to).with(membership.user))

        described_class.new.perform(membership.id)

        expect(AmbassadorTaskAssignmentCreator)
          .to_not(have_received(:assign_all_ambassador_tasks_to))
      end
    end

    context "given an ambassador" do
      it "assigns all given task to the given ambassador" do
        user = FactoryBot.create(:user_confirmed)
        membership = FactoryBot.create(:membership_ambassador, user_id: user.id)
        allow(AmbassadorTaskAssignmentCreator)
          .to(receive(:assign_all_ambassador_tasks_to).with(user))

        described_class.new.perform(membership.id)

        expect(AmbassadorTaskAssignmentCreator)
          .to(have_received(:assign_all_ambassador_tasks_to).once)
      end
    end
  end
end
