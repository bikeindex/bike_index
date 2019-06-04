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

      context "sorting by completion time" do
        it "sorts in ascending order of completion by default" do
          ordered_assignments =
            FactoryBot
              .create_list(:ambassador_task_assignment, 3, :completed)
              .map(&:id)

          get admin_ambassador_task_assignments_path

          assignments = assigns(:ambassador_task_assignments).map(&:id)
          expect(assignments).to eq(ordered_assignments)
        end

        it "sorts in descending order of completion if passed :asc" do
          ordered_assignments =
            FactoryBot
              .create_list(:ambassador_task_assignment, 3, :completed)
              .map(&:id)

          get admin_ambassador_task_assignments_path,
              sort: :completed_at,
              direction: :asc

          assignments = assigns(:ambassador_task_assignments).map(&:id)
          expect(assignments).to eq(ordered_assignments)
        end

        it "sorts in descending order of completion if passed :desc" do
          ordered_assignments =
            FactoryBot
              .create_list(:ambassador_task_assignment, 3, :completed)
              .map(&:id)

          get admin_ambassador_task_assignments_path,
              sort: :completed_at,
              direction: :desc

          assignments = assigns(:ambassador_task_assignments).map(&:id)
          expect(assignments).to eq(ordered_assignments.reverse)
        end
      end

      context "sorting by organization name" do
        it "sorts in ascending order if passed :asc" do
          org_names =
            FactoryBot
              .create_list(:ambassador_task_assignment, 3, :completed)
              .map { |a| a.ambassador.current_ambassador_organization.name }

          get admin_ambassador_task_assignments_path,
              sort: :organization_name,
              direction: :asc

          assignments =
            assigns(:ambassador_task_assignments)
              .map { |a| a.ambassador.current_ambassador_organization.name }

          expect(assignments).to eq(org_names)
        end

        it "sorts in descending order if passed :desc" do
          org_names =
            FactoryBot
              .create_list(:ambassador_task_assignment, 3, :completed)
              .map { |a| a.ambassador.current_ambassador_organization.name }

          get admin_ambassador_task_assignments_path,
              sort: :organization_name,
              direction: :desc

          assignments =
            assigns(:ambassador_task_assignments)
              .map { |a| a.ambassador.current_ambassador_organization.name }

          expect(assignments).to eq(org_names.reverse)
        end
      end

      context "sorting by task ambassador name" do
        it "sorts in ascending order if passed :asc" do
          ambassador_names =
            FactoryBot
              .create_list(:ambassador_task_assignment, 3, :completed)
              .map(&:ambassador_name)

          get admin_ambassador_task_assignments_path,
              sort: :ambassador_name,
              direction: :asc

          assignments = assigns(:ambassador_task_assignments).map(&:ambassador_name)
          expect(assignments).to eq(ambassador_names)
        end

        it "sorts in descending order if passed :desc" do
          ambassador_names =
            FactoryBot
              .create_list(:ambassador_task_assignment, 3, :completed)
              .map(&:ambassador_name)

          get admin_ambassador_task_assignments_path,
              sort: :ambassador_name,
              direction: :desc

          assignments = assigns(:ambassador_task_assignments).map(&:ambassador_name)
          expect(assignments).to eq(ambassador_names.reverse)
        end
      end

      context "sorting by task title" do
        it "sorts in ascending order if passed :asc" do
          task_titles =
            FactoryBot
              .create_list(:ambassador_task_assignment, 3, :completed)
              .map(&:title)

          get admin_ambassador_task_assignments_path,
              sort: :task_title,
              direction: :asc

          assignments = assigns(:ambassador_task_assignments).map(&:title)
          expect(assignments).to eq(task_titles)
        end

        it "sorts in descending order if passed :desc" do
          task_titles =
            FactoryBot
              .create_list(:ambassador_task_assignment, 3, :completed)
              .map(&:title)

          get admin_ambassador_task_assignments_path,
              sort: :task_title,
              direction: :desc

          assignments = assigns(:ambassador_task_assignments).map(&:title)
          expect(assignments).to eq(task_titles.reverse)
        end
      end
    end
  end
end
