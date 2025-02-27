require "rails_helper"

RSpec.describe OrganizationRole, type: :model do
  describe "#ensure_ambassador_tasks_assigned!" do
    context "given an ambassador organization" do
      it "enqueues a job to assign ambassador tasks to the given user" do
        Sidekiq::Job.clear_all
        user = FactoryBot.create(:user_confirmed)
        org = FactoryBot.create(:organization_ambassador)
        tasks = FactoryBot.create_list(:ambassador_task, 2)
        expect(AmbassadorTaskAssignment.count).to eq(0)

        Sidekiq::Job.clear_all
        expect {
          FactoryBot.create(:organization_role_claimed, organization: org, user: user)
        }.to change(ProcessOrganizationRoleJob.jobs, :count).by 1
        Sidekiq::Job.drain_all

        expect(AmbassadorTaskAssignment.count).to eq(2)
        expect(Ambassador.find(user.id).ambassador_tasks).to match_array(tasks)
      end
    end

    context "given a non-ambassador organization" do
      it "does not enqueue a job to assign ambassador tasks to the given user" do
        user = FactoryBot.create(:user_confirmed)
        org = FactoryBot.create(:organization)
        expect(AmbassadorTaskAssignment.count).to eq(0)

        FactoryBot.create(:organization_role_claimed, organization: org, user: user)
        Sidekiq::Job.drain_all

        expect(AmbassadorTaskAssignment.count).to eq(0)
      end
    end
  end

  describe ".ambassador_organizations" do
    it "returns all and only ambassador organizations" do
      FactoryBot.create(:organization_role_claimed)
      ambassador_orgs = FactoryBot.create_list(:organization_role_ambassador, 3)
      found_orgs = OrganizationRole.ambassador_organizations
      expect(found_orgs.order(:created_at)).to eq(ambassador_orgs.sort_by(&:created_at))
    end
  end

  describe "admin?" do
    context "admin" do
      it "returns true" do
        organization_role = OrganizationRole.new(role: "admin")
        expect(organization_role.admin?).to be_truthy
      end
    end
    context "member" do
      it "returns true" do
        organization_role = OrganizationRole.new(role: "member")
        expect(organization_role.admin?).to be_falsey
      end
    end
  end

  describe "ambassador organization_role without user" do
    let!(:organization) { FactoryBot.create(:organization_ambassador) }
    let!(:ambassador_task) { FactoryBot.create(:ambassador_task) }
    let(:email) { "new@ambassador.edu" }
    let(:organization_role) { FactoryBot.build(:organization_role, organization: organization, invited_email: email) }
    it "creates the tasks when it can create the tasks" do
      Sidekiq::Job.clear_all
      organization_role.save
      expect(organization_role.ambassador?).to be_truthy
      Sidekiq::Job.drain_all
      user = FactoryBot.create(:user, email: email)
      Sidekiq::Job.drain_all
      user.reload
      expect(user.ambassador?).to be_truthy
      expect(user.ambassador_tasks).to eq([ambassador_task])
    end
  end
end
