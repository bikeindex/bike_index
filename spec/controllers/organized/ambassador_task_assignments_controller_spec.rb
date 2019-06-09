require "rails_helper"

RSpec.describe Organized::AmbassadorTaskAssignmentsController, type: :controller do
  describe "#update" do
    include_context :logged_in_as_ambassador

    context "given completed: false" do
      it "unsets the task's completed_at value" do
        assignment = FactoryBot.create(:ambassador_task_assignment, :completed)

        patch :update,
              organization_id: organization,
              id: assignment,
              completed: "false"

        expect(response).to redirect_to(organization_ambassador_dashboard_url)
        expect(assignment.reload.completed_at).to be_nil
        expect(flash[:info]).to match("status updated")
        expect(flash[:error]).to be_blank
      end
    end

    context "given completed: true" do
      it "sets the task's completed_at value" do
        assignment = FactoryBot.create(:ambassador_task_assignment)
        expect(assignment.reload.completed_at).to be_nil

        patch :update,
              organization_id: organization,
              id: assignment,
              completed: "true"

        expect(response).to redirect_to(organization_ambassador_dashboard_url)
        expect(assignment.reload.completed_at).to_not be_nil
        expect(flash[:info]).to match("status updated")
        expect(flash[:error]).to be_blank
      end
    end

    context "given a failed update" do
      it "sets the flash error message" do
        assignment = FactoryBot.create(:ambassador_task_assignment)
        allow(assignment).to receive(:update_attributes).and_return(false)
        allow(AmbassadorTaskAssignment).to receive(:find).and_return(assignment)

        patch :update,
              organization_id: organization,
              id: assignment,
              completed: "true"

        expect(response).to redirect_to(organization_ambassador_dashboard_url)
        expect(assignment.reload.completed_at).to_not be_present
        expect(flash[:info]).to be_blank
        expect(flash[:error]).to match("Could not update")
      end
    end
  end
end
