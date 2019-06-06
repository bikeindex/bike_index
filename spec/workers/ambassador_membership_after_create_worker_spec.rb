require "spec_helper"

describe AmbassadorMembershipAfterCreateWorker do
  describe "#perform" do
    context "given a not found membership id" do
      it "raises RecordNotFound" do
        job = -> { described_class.new.perform(0) }
        expect { job.call }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "given a non-ambassador membership id" do
      it "no-ops" do
        membership = FactoryBot.create(:existing_membership)
        allow(AmbassadorTaskAssignmentCreator)
          .to(receive(:assign_all_ambassador_tasks_to).with(membership.user_id))

        described_class.new.perform(membership.id)

        expect(AmbassadorTaskAssignmentCreator)
          .to_not(have_received(:assign_all_ambassador_tasks_to))
      end
    end

    context "given an ambassador membership id" do
      it "assigns all given task to the given ambassador" do
        membership = FactoryBot.create(:membership_ambassador)
        allow(AmbassadorTaskAssignmentCreator)
          .to(receive(:assign_all_ambassador_tasks_to).with(membership.user_id))

        described_class.new.perform(membership.id)

        expect(AmbassadorTaskAssignmentCreator)
          .to(have_received(:assign_all_ambassador_tasks_to).once)
      end
    end
  end
end
