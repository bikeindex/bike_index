require "spec_helper"

describe AmbassadorTaskAssignment, type: :model do
  let(:non_ambassador) { FactoryBot.create(:user) }
  let(:ambassador) { FactoryBot.create(:ambassador) }
  let(:ambassador_task) { FactoryBot.create(:ambassador_task) }

  describe "#completed" do
    it "returns task assignments marked complete within the last 2 hours" do
      assignment1 = FactoryBot.create(:ambassador_task_assignment, :completed_a_day_ago, ambassador: ambassador)
      assignment2 = FactoryBot.create(:ambassador_task_assignment, :completed_an_hour_ago, ambassador: ambassador)
      _assignment3 = FactoryBot.create(:ambassador_task_assignment, ambassador: ambassador)

      completed = ambassador.ambassador_task_assignments.completed
      expect(completed).to match_array([assignment1, assignment2])
    end
  end

  describe "#pending_completion" do
    it "returns task assignments marked completed within 2 hours or not at all" do
      _assignment1 = FactoryBot.create(:ambassador_task_assignment, :completed_a_day_ago, ambassador: ambassador)
      assignment2 = FactoryBot.create(:ambassador_task_assignment, :completed_an_hour_ago, ambassador: ambassador)
      assignment3 = FactoryBot.create(:ambassador_task_assignment, ambassador: ambassador)

      pending_completion = ambassador.ambassador_task_assignments.pending_completion
      expect(pending_completion).to match_array([assignment2, assignment3])
    end
  end

  describe "#locked_completed" do
    it "returns task assignments marked complete more than 2 hours ago" do
      assignment1 = FactoryBot.create(:ambassador_task_assignment, :completed_a_day_ago, ambassador: ambassador)
      _assignment2 = FactoryBot.create(:ambassador_task_assignment, :completed_an_hour_ago, ambassador: ambassador)
      _assignment3 = FactoryBot.create(:ambassador_task_assignment, ambassador: ambassador)

      locked_completed = ambassador.ambassador_task_assignments.locked_completed
      expect(locked_completed).to match_array([assignment1])
    end
  end

  context "validates unqiueness of ambassador scoped to the user" do
    it "is valid if the task assignment is unique per-user" do
      assignment = described_class.new(ambassador: ambassador,
                                       ambassador_task: ambassador_task)
      expect(assignment).to be_valid
    end

    it "is invalid if the task assignment is non-unique per-user" do
      assignment1 = FactoryBot.create(:ambassador_task_assignment)
      ambassador = assignment1.ambassador
      task = assignment1.ambassador_task

      assignment2 = described_class.new(ambassador: ambassador, ambassador_task: task)

      expect(assignment2).to be_invalid
      expect(assignment2.errors[:ambassador_task]).to eq(["has already been taken"])
    end
  end

  describe ".completed_assignments" do
    context "filtering" do
      it "filters by the given organization_id" do
        a1 = FactoryBot.create(:ambassador_task_assignment, :completed)
        FactoryBot.create(:ambassador_task_assignment, :completed)

        result = described_class.completed_assignments(
          filters: { organization_id: a1.organization.id },
        )

        expect(result).to match_array([a1])
      end

      it "filters by the given task" do
        a1 = FactoryBot.create(:ambassador_task_assignment, :completed)
        FactoryBot.create(:ambassador_task_assignment, :completed)

        result = described_class.completed_assignments(
          filters: { ambassador_task_id: a1.ambassador_task.id },
        )

        expect(result).to match_array([a1])
      end

      it "filters by the given ambassador" do
        a1 = FactoryBot.create(:ambassador_task_assignment, :completed)
        FactoryBot.create(:ambassador_task_assignment, :completed)

        result = described_class.completed_assignments(
          filters: { ambassador_id: a1.ambassador.id },
        )

        expect(result).to match_array([a1])
      end

      it "filters by combinations of filter columns" do
        a1 = FactoryBot.create(:ambassador_task_assignment, :completed)
        a2 = FactoryBot.create(:ambassador_task_assignment, :completed,
                               organization: a1.organization,
                               ambassador_task: a1.ambassador_task)
        a3 = FactoryBot.create(:ambassador_task_assignment, :completed,
                               organization: a1.organization,
                               ambassador_task: a1.ambassador_task)
        FactoryBot.create(:ambassador_task_assignment, :completed)

        result = described_class.completed_assignments(
          filters: {
            organization_id: a1.organization.id,
            ambassador_task_id: a3.ambassador_task.id,
          },
        )

        expect(result).to match_array([a1, a2, a3])
      end
    end

    context "sorting by completion time" do
      it "sorts in descending order of completion by default" do
        ordered_assignments =
          FactoryBot
            .create_list(:ambassador_task_assignment, 3, :completed)
            .map(&:id)

        result = described_class.completed_assignments

        expect(result.map(&:id)).to eq(ordered_assignments.reverse)
      end

      it "sorts in descending order of completion if passed asc" do
        ordered_assignments =
          FactoryBot
            .create_list(:ambassador_task_assignment, 3, :completed)
            .map(&:id)

        result = described_class.completed_assignments(sort: { completed_at: :asc })

        expect(result.map(&:id)).to eq(ordered_assignments)
      end

      it "sorts in descending order of completion if passed desc" do
        ordered_assignments =
          FactoryBot
            .create_list(:ambassador_task_assignment, 3, :completed)
            .map(&:id)

        result = described_class.completed_assignments(sort: { completed_at: :desc })

        expect(result.map(&:id)).to eq(ordered_assignments.reverse)
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

        result = described_class.completed_assignments(sort: { organization_name: :asc })

        # Tasks should be sorted by name of the ambassador's *current* ambassador org
        names = result.map { |a| a.ambassador.current_ambassador_organization.name }
        expect(names).to eq(["A", "C", "X"])
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

        result = described_class.completed_assignments(sort: { organization_name: :desc })

        # Tasks should be sorted by name of the ambassador's *current* ambassador org
        names = result.map { |a| a.ambassador.current_ambassador_organization.name }
        expect(names).to eq(["Z", "X", "B"])
      end
    end

    context "sorting by task ambassador name" do
      it "sorts in ascending order if passed asc" do
        ambassador_names =
          FactoryBot
            .create_list(:ambassador_task_assignment, 3, :completed)
            .map(&:ambassador_name)

        result =
          described_class
            .completed_assignments(sort: { ambassador_name: :asc })

        expect(result.map(&:ambassador_name)).to eq(ambassador_names)
      end

      it "sorts in descending order if passed desc" do
        ambassador_names =
          FactoryBot
            .create_list(:ambassador_task_assignment, 3, :completed)
            .map(&:ambassador_name)

        result =
          described_class
            .completed_assignments(sort: { ambassador_name: :desc })

        expect(result.map(&:ambassador_name)).to eq(ambassador_names.reverse)
      end
    end

    context "sorting by task title" do
      it "sorts in ascending order if passed asc" do
        task_titles =
          FactoryBot
            .create_list(:ambassador_task_assignment, 3, :completed)
            .map(&:title)

        result =
          described_class
            .completed_assignments(sort: { ambassador_task_title: :asc })

        expect(result.map(&:title)).to eq(task_titles)
      end

      it "sorts in descending order if passed desc" do
        task_titles =
          FactoryBot
            .create_list(:ambassador_task_assignment, 3, :completed)
            .map(&:title)

        result =
          described_class
            .completed_assignments(sort: { ambassador_task_title: :desc })

        expect(result.map(&:title)).to eq(task_titles.reverse)
      end
    end
  end
end
