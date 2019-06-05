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

      context "filtering by organization" do
        it "filters by the given organization id" do
          a1 = FactoryBot.create(:ambassador_task_assignment, :completed)
          FactoryBot.create(:ambassador_task_assignment, :completed)

          get admin_ambassador_task_assignments_path,
              organization_id: a1.organization.id

          expect(assigns(:ambassador_task_assignments)).to match_array([a1])
        end
      end

      context "sorting by completion time" do
        it "sorts in descending order of completion by default" do
          ordered_assignments =
            FactoryBot
              .create_list(:ambassador_task_assignment, 3, :completed)
              .map(&:id)

          get admin_ambassador_task_assignments_path

          assignments = assigns(:ambassador_task_assignments).map(&:id)
          expect(assignments).to eq(ordered_assignments.reverse)
        end

        it "sorts in descending order of completion if passed asc" do
          ordered_assignments =
            FactoryBot
              .create_list(:ambassador_task_assignment, 3, :completed)
              .map(&:id)

          get admin_ambassador_task_assignments_path,
              sort: "completed_at",
              direction: "asc"

          assignments = assigns(:ambassador_task_assignments).map(&:id)
          expect(assignments).to eq(ordered_assignments)
        end

        it "sorts in descending order of completion if passed desc" do
          ordered_assignments =
            FactoryBot
              .create_list(:ambassador_task_assignment, 3, :completed)
              .map(&:id)

          get admin_ambassador_task_assignments_path,
              sort: "completed_at",
              direction: "desc"

          assignments = assigns(:ambassador_task_assignments).map(&:id)
          expect(assignments).to eq(ordered_assignments.reverse)
        end
      end

      context "sorting by organization name" do
        it "sorts in ascending order if passed asc" do
          org1 = FactoryBot.create(:organization_ambassador, name: "A")
          FactoryBot.create(:ambassador_task_assignment, :completed, organization: org1)
          org2 = FactoryBot.create(:organization_ambassador, name: "B")
          FactoryBot.create(:ambassador_task_assignment, :completed, organization: org2)
          org3 = FactoryBot.create(:organization_ambassador, name: "C")
          FactoryBot.create(:ambassador_task_assignment, :completed, organization: org3)

          # ambassador for group "B" joins group "X"
          org4 = FactoryBot.create(:organization_ambassador, name: "X")
          FactoryBot.create(:membership_ambassador, user: Ambassador.second, organization: org4)

          get admin_ambassador_task_assignments_path,
              sort: "organization_name",
              direction: "asc"

          assignments =
            assigns(:ambassador_task_assignments)
              .map { |a| a.ambassador.current_ambassador_organization.name }

          # Tasks should be sorted by name of the ambassador's *current* ambassador org
          expect(assignments).to eq(["A", "C", "X"])
        end

        it "sorts in descending order if passed desc" do
          org1 = FactoryBot.create(:organization_ambassador, name: "X")
          FactoryBot.create(:ambassador_task_assignment, :completed, organization: org1)
          org2 = FactoryBot.create(:organization_ambassador, name: "Y")
          FactoryBot.create(:ambassador_task_assignment, :completed, organization: org2)
          org3 = FactoryBot.create(:organization_ambassador, name: "Z")
          FactoryBot.create(:ambassador_task_assignment, :completed, organization: org3)

          # ambassador for group "Y" joins group "B"
          org4 = FactoryBot.create(:organization_ambassador, name: "B")
          FactoryBot.create(:membership_ambassador, user: Ambassador.second, organization: org4)

          get admin_ambassador_task_assignments_path,
              sort: "organization_name",
              direction: "desc"

          assignments =
            assigns(:ambassador_task_assignments)
              .map { |a| a.ambassador.current_ambassador_organization.name }

          # Tasks should be sorted by name of the ambassador's *current* ambassador org
          expect(assignments).to eq(["Z", "X", "B"])
        end
      end

      context "sorting by task ambassador name" do
        it "sorts in ascending order if passed asc" do
          ambassador_names =
            FactoryBot
              .create_list(:ambassador_task_assignment, 3, :completed)
              .map(&:ambassador_name)

          get admin_ambassador_task_assignments_path,
              sort: "ambassador_name",
              direction: "asc"

          assignments = assigns(:ambassador_task_assignments).map(&:ambassador_name)
          expect(assignments).to eq(ambassador_names)
        end

        it "sorts in descending order if passed desc" do
          ambassador_names =
            FactoryBot
              .create_list(:ambassador_task_assignment, 3, :completed)
              .map(&:ambassador_name)

          get admin_ambassador_task_assignments_path,
              sort: "ambassador_name",
              direction: "desc"

          assignments = assigns(:ambassador_task_assignments).map(&:ambassador_name)
          expect(assignments).to eq(ambassador_names.reverse)
        end
      end

      context "sorting by task title" do
        it "sorts in ascending order if passed asc" do
          task_titles =
            FactoryBot
              .create_list(:ambassador_task_assignment, 3, :completed)
              .map(&:title)

          get admin_ambassador_task_assignments_path,
              sort: "task_title",
              direction: "asc"

          assignments = assigns(:ambassador_task_assignments).map(&:title)
          expect(assignments).to eq(task_titles)
        end

        it "sorts in descending order if passed desc" do
          task_titles =
            FactoryBot
              .create_list(:ambassador_task_assignment, 3, :completed)
              .map(&:title)

          get admin_ambassador_task_assignments_path,
              sort: "task_title",
              direction: "desc"

          assignments = assigns(:ambassador_task_assignments).map(&:title)
          expect(assignments).to eq(task_titles.reverse)
        end
      end
    end
  end
end
