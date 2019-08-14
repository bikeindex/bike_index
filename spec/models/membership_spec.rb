require "rails_helper"

RSpec.describe Membership, type: :model do
  describe "#ensure_ambassador_tasks_assigned!" do
    context "given an ambassador organization" do
      it "enqueues a job to assign ambassador tasks to the given user" do
        Sidekiq::Worker.clear_all
        user = FactoryBot.create(:user_confirmed)
        org = FactoryBot.create(:organization_ambassador)
        tasks = FactoryBot.create_list(:ambassador_task, 2)
        expect(AmbassadorTaskAssignment.count).to eq(0)

        Sidekiq::Worker.clear_all
        expect do
          membership = FactoryBot.create(:membership_claimed, organization: org, user: user)
          membership.enqueue_processing_worker # TODO: Rails 5 update
        end.to change(ProcessMembershipWorker.jobs, :count).by 1
        Sidekiq::Worker.drain_all

        expect(AmbassadorTaskAssignment.count).to eq(2)
        expect(Ambassador.find(user.id).ambassador_tasks).to match_array(tasks)
      end
    end

    context "given a non-ambassador organization" do
      it "does not enqueue a job to assign ambassador tasks to the given user" do
        user = FactoryBot.create(:user_confirmed)
        org = FactoryBot.create(:organization)
        expect(AmbassadorTaskAssignment.count).to eq(0)

        membership = FactoryBot.create(:membership_claimed, organization: org, user: user)
        membership.enqueue_processing_worker # TODO: Rails 5 update
        Sidekiq::Worker.drain_all

        expect(AmbassadorTaskAssignment.count).to eq(0)
      end
    end
  end

  describe ".ambassador_organizations" do
    it "returns all and only ambassador organizations" do
      FactoryBot.create(:membership_claimed)
      ambassador_orgs = FactoryBot.create_list(:membership_ambassador, 3)
      found_orgs = Membership.ambassador_organizations
      expect(found_orgs.order(:created_at)).to eq(ambassador_orgs.sort_by(&:created_at))
    end
  end

  describe "admin?" do
    context "admin" do
      it "returns true" do
        membership = Membership.new(role: "admin")
        expect(membership.admin?).to be_truthy
      end
    end
    context "member" do
      it "returns true" do
        membership = Membership.new(role: "member")
        expect(membership.admin?).to be_falsey
      end
    end
  end

  describe "ambassador membership without user" do
    let!(:organization) { FactoryBot.create(:organization_ambassador) }
    let!(:ambassador_task) { FactoryBot.create(:ambassador_task) }
    let(:email) { "new@ambassador.edu" }
    let(:membership) { FactoryBot.build(:membership, organization: organization, invited_email: email) }
    it "creates the tasks when it can create the tasks" do
      Sidekiq::Worker.clear_all
      membership.save
      expect(membership.ambassador?).to be_truthy
      membership.enqueue_processing_worker # TODO: Rails 5 update, after commit
      Sidekiq::Worker.drain_all
      user = FactoryBot.create(:user, email: email)
      user.perform_create_jobs # TODO: Rails 5 update
      Sidekiq::Worker.drain_all
      user.reload
      expect(user.ambassador?).to be_truthy
      expect(user.ambassador_tasks).to eq([ambassador_task])
    end
  end
end
