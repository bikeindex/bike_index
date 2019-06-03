require "spec_helper"

RSpec.describe Admin::AmbassadorTaskAssignmentsController, type: :request do
  before { allow(User).to receive(:from_auth) { user } }
  let(:user) { FactoryBot.create(:admin) }

  describe "#index" do
    context "when logged in as a super admin" do
      it "renders the index template" do
        get(admin_ambassador_task_assignments_path)
        expect(response).to be_ok
        expect(response).to render_template("admin/ambassador_task_assignments/index")
      end

      context "sorting by completion time" do
        it "sorts in ascending order if passed :asc"
        it "sorts in descending order if passed :desc"
      end

      context "sorting by organization name" do
        it "sorts in ascending order if passed :asc"
        it "sorts in descending order if passed :desc"
      end

      context "sorting by task ambassador name" do
        it "sorts in ascending order if passed :asc"
        it "sorts in descending order if passed :desc"
      end

      context "sorting by task title" do
        it "sorts in ascending order if passed :asc"
        it "sorts in descending order if passed :desc"
      end
    end
  end
end
