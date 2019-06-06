require "spec_helper"

RSpec.describe Admin::AmbassadorTaskAssignmentsController, type: :request do
  before { allow(User).to receive(:from_auth) { user } }
  let(:user) { FactoryBot.create(:admin) }

  describe "#index" do
    context "when logged in as a super admin" do
      it "renders the index template with completed ambassador tasks" do
        _pending = FactoryBot.create(:ambassador_task_assignment)
        completed = FactoryBot.create(:ambassador_task_assignment, :completed)

        get admin_ambassador_task_assignments_path

        expect(response).to be_ok
        expect(response).to render_template("admin/ambassador_task_assignments/index")
        expect(assigns(:ambassador_task_assignments)).to eq([completed])
      end
    end
  end
end
