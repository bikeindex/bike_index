require "rails_helper"

RSpec.describe Membership, type: :model do
  describe "#ensure_ambassador_tasks_assigned!" do
    context "given an ambassador organization" do
      it "enqueues a job to assign ambassador tasks to the given user" do
        user = FactoryBot.create(:user_confirmed)
        org = FactoryBot.create(:organization_ambassador)
        tasks = FactoryBot.create_list(:ambassador_task, 2)
        expect(AmbassadorTaskAssignment.count).to eq(0)

        Membership.create(organization: org, user: user)
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

        Membership.create(organization: org, user: user)
        Sidekiq::Worker.drain_all

        expect(AmbassadorTaskAssignment.count).to eq(0)
      end
    end
  end

  describe ".ambassador_organizations" do
    it "returns all and only ambassador organizations" do
      FactoryBot.create(:existing_membership)
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
end
