require "rails_helper"

RSpec.describe Organized::AmbassadorTaskAssignmentsController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/ambassador_task_assignments" }

  describe "#update" do
    include_context :request_spec_logged_in_as_ambassador

    context "given completed: false" do
      it "unsets the task's completed_at value" do
        assignment = FactoryBot.create(:ambassador_task_assignment, :completed)

        patch "#{base_url}/#{assignment.to_param}",
          params: {
            completed: "false"
          }

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

        patch "#{base_url}/#{assignment.to_param}",
          params: {
            completed: "true"
          }

        expect(response).to redirect_to(organization_ambassador_dashboard_url)
        expect(assignment.reload.completed_at).to_not be_nil
        expect(flash[:info]).to match("status updated")
        expect(flash[:error]).to be_blank
      end
    end

    context "given a failed update" do
      it "sets the flash error message" do
        assignment = FactoryBot.create(:ambassador_task_assignment)
        allow(assignment).to receive(:update).and_return(false)
        allow(AmbassadorTaskAssignment).to receive(:find).and_return(assignment)

        patch "#{base_url}/#{assignment.to_param}",
          params: {
            completed: "true"
          }

        expect(response).to redirect_to(organization_ambassador_dashboard_url)
        expect(assignment.reload.completed_at).to_not be_present
        expect(flash[:info]).to be_blank
        expect(flash[:error]).to match("Could not update")
      end
    end
  end
end
