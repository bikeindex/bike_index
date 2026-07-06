require "rails_helper"

RSpec.describe BugReport, type: :model do
  describe "set_calculated_attributes" do
    let(:bug_report) { FactoryBot.create(:bug_report, email: "SomeOne@example.com ", tags: ["Broken ", "search", "broken", ""]) }

    it "normalizes email and tags" do
      expect(bug_report).to have_attributes(email: "someone@example.com",
        tags: %w[broken search], user_id: nil, is_member: false,
        is_paid_organization: false, is_paid_organization_staff: false)
    end

    context "with a user" do
      let(:user) { FactoryBot.create(:user_confirmed) }
      let(:bug_report) { FactoryBot.create(:bug_report, email: user.email) }

      it "associates the user" do
        expect(bug_report).to have_attributes(user_id: user.id, is_member: false,
          is_paid_organization: false, is_paid_organization_staff: false)
      end

      context "with an active membership" do
        let!(:membership) { FactoryBot.create(:membership, user:) }

        it "is_member" do
          expect(bug_report).to have_attributes(user_id: user.id, is_member: true,
            is_paid_organization: false, is_paid_organization_staff: false)
        end
      end

      context "in a paid organization" do
        let(:organization) { FactoryBot.create(:organization, :paid) }
        let!(:organization_role) { FactoryBot.create(:organization_role_claimed, user:, organization:, role:) }
        let(:role) { "member" }

        it "is_paid_organization" do
          expect(bug_report).to have_attributes(user_id: user.id, is_member: false,
            is_paid_organization: true, is_paid_organization_staff: false)
        end

        context "with an admin role" do
          let(:role) { "admin" }

          it "is_paid_organization_staff" do
            expect(bug_report).to have_attributes(user_id: user.id, is_member: false,
              is_paid_organization: true, is_paid_organization_staff: true)
          end
        end
      end
    end
  end

  describe "versioning" do
    include_context :with_paper_trail

    let(:bug_report) { FactoryBot.create(:bug_report, tags: ["search"]) }

    it "creates versions for tracked attributes" do
      expect(bug_report.versions.count).to eq 1
      expect(bug_report.versions.last.event).to eq "create"

      bug_report.update!(tags: ["search", "broken"], github_pull_request: 3805)
      expect(bug_report.versions.count).to eq 2
      target_changes = {tags: [["search"], ["broken", "search"]], github_pull_request: [nil, 3805]}
      expect(bug_report.versions.last.object_changes).to eq target_changes.as_json

      # untracked attributes don't create versions
      bug_report.update!(subject: "A new subject")
      expect(bug_report.versions.count).to eq 2
    end
  end

  describe "with_tag and all_tags" do
    let!(:bug_report) { FactoryBot.create(:bug_report, tags: %w[search broken]) }
    let!(:bug_report_other) { FactoryBot.create(:bug_report, tags: ["search"]) }

    it "matches bug reports with the tag" do
      expect(BugReport.with_tag("broken").pluck(:id)).to eq([bug_report.id])
      expect(BugReport.with_tag("search").pluck(:id)).to match_array([bug_report.id, bug_report_other.id])
      expect(BugReport.all_tags).to eq(%w[broken search])
    end
  end

  describe "github_pull_request_url" do
    let(:bug_report) { FactoryBot.build(:bug_report, github_pull_request: 3805) }

    it "returns the pull request url" do
      expect(bug_report.github_pull_request_url).to eq "https://github.com/bikeindex/bike_index/pull/3805"
      bug_report.github_pull_request = nil
      expect(bug_report.github_pull_request_url).to be_nil
    end
  end
end
