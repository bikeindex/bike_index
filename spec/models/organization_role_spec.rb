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
        }.to change(Users::ProcessOrganizationRoleJob.jobs, :count).by 1
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

  describe ".create_for_user_email_domain" do
    let(:invited_email) { "student@sso.edu" }
    let(:organization) { FactoryBot.create(:organization) }
    let!(:user) { FactoryBot.create(:user_confirmed, email: invited_email) }
    let(:create_for_user_email_domain) { OrganizationRole.create_for_user_email_domain(organization_id: organization.id, invited_email:) }

    it "grants the existing user the default member role" do
      expect(create_for_user_email_domain.organization_id).to eq organization.id
      expect(create_for_user_email_domain.role).to eq "member"
      expect(create_for_user_email_domain.user).to eq user
    end

    it "returns the existing role rather than a second one" do
      existing = create_for_user_email_domain
      expect {
        expect(OrganizationRole.create_for_user_email_domain(organization_id: organization.id, invited_email: "Student@SSO.edu "))
          .to eq existing
      }.to_not change(OrganizationRole, :count)
    end

    context "invited to a different organization" do
      let!(:other_organization_role) do
        FactoryBot.create(:organization_role, invited_email:,
          organization: FactoryBot.create(:organization))
      end

      it "creates the role for this organization anyway" do
        expect(create_for_user_email_domain.organization_id).to eq organization.id
        expect(create_for_user_email_domain.id).to_not eq other_organization_role.id
      end
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

  describe "organization_access_token" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:organization_role) { FactoryBot.create(:organization_role, organization:, role:) }

    context "admin" do
      let(:role) { "admin" }
      it "returns the organization's token" do
        expect(organization_role.organization_access_token).to eq organization.access_token
      end
    end

    context "member" do
      let(:role) { "member" }
      it "returns the organization's token" do
        expect(organization_role.organization_access_token).to eq organization.access_token
      end
    end

    context "member_no_bike_edit" do
      let(:role) { "member_no_bike_edit" }
      it "returns nil" do
        expect(organization.access_token).to be_present
        expect(organization_role.organization_access_token).to be_nil
      end
    end
  end

  describe "admin_text_search" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:user) { FactoryBot.create(:user_confirmed, name: "Jane Smith", email: "JANE@Example.COM") }
    let!(:organization_role) { FactoryBot.create(:organization_role_claimed, organization:, user:, invited_email: "JANE@Example.COM") }

    it "finds by invited_email case-insensitively" do
      expect(OrganizationRole.admin_text_search("jane@example.com ").pluck(:id)).to eq([organization_role.id])
      expect(OrganizationRole.admin_text_search("jane@example").pluck(:id)).to eq([organization_role.id])
      expect(OrganizationRole.admin_text_search("jane smith").pluck(:id)).to eq([organization_role.id])
      expect(OrganizationRole.admin_text_search("jane s").pluck(:id)).to eq([organization_role.id])
      expect(OrganizationRole.admin_text_search("e@EXAMPLE.COM").pluck(:id)).to eq([organization_role.id])
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
