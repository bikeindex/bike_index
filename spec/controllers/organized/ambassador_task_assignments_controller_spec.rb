require "spec_helper"

describe Organized::AmbassadorTaskAssignmentsController, type: :controller do
  describe "#update" do
    include_context :logged_in_as_ambassador

    context "given completed: false" do
      it "unsets the task's completed_at value" do
        task = FactoryBot.create(:ambassador_task_assignment, :completed)

        patch :update,
              organization_id: organization,
              id: task,
              completed: false,
              format: :json

        expect(response.status).to eq(200)
        expect(task.reload.completed_at).to be_nil
      end
    end

    context "given completed: true" do
      it "sets the task's completed_at value" do
        task = FactoryBot.create(:ambassador_task_assignment)

        patch :update,
              organization_id: organization,
              id: task,
              completed: true,
              format: :json

        expect(response.status).to eq(200)
        expect(task.reload.completed_at).to_not be_nil
      end
    end
  end
end
