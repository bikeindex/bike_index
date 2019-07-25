require "rails_helper"

RSpec.describe Ambassador, type: :model do
  describe ".all" do
    it "returns all ambassadors" do
      FactoryBot.create(:user)
      created_ambassadors = FactoryBot.create_list(:ambassador, 3).sort
      ambassadors = Ambassador.all.sort
      expect(ambassadors).to eq(created_ambassadors)
    end
  end

  describe "#ambassador_organizations" do
    it "returns any associated ambassador organizations" do
      ambassador = FactoryBot.create(:ambassador)
      FactoryBot.create_list(:membership_ambassador, 3, user: ambassador)
      FactoryBot.create_list(:membership_claimed, 2, user: ambassador)

      expect(ambassador.ambassador_organizations.count).to eq(4)
      expect(ambassador.organizations.count).to eq(6)
    end
  end

  describe "#current_ambassador_organization" do
    it "returns the most recently associated ambassador organization" do
      ambassador = FactoryBot.create(:ambassador)
      org1 = FactoryBot.create(:organization_ambassador)
      org2 = FactoryBot.create(:organization_ambassador)
      FactoryBot.create(:membership_ambassador, user: ambassador, organization: org2)
      new_ambassadorship = FactoryBot.create(:membership_ambassador, user: ambassador, organization: org1)
      FactoryBot.create(:membership_claimed, user: ambassador)

      current_org = ambassador.current_ambassador_organization

      expect(current_org).to eq(new_ambassadorship.organization)
      expect(ambassador.organizations.count).to eq(4)
    end
  end

  describe "#percent_complete" do
    context "given no associated tasks" do
      it "returns 0 as a Float" do
        ambassador = FactoryBot.create(:ambassador)
        expect(ambassador.percent_complete).to eq(0.0)
      end
    end

    context "given two completed of three tasks" do
      it "returns 2/3 as a Float rounded to 2" do
        ambassador = FactoryBot.create(:ambassador)
        FactoryBot.create_list(:ambassador_task_assignment, 2, :completed, ambassador: ambassador)
        FactoryBot.create(:ambassador_task_assignment, ambassador: ambassador)
        expect(ambassador.percent_complete).to eq(0.67)
      end
    end

    context "given three completed of three tasks" do
      it "returns 1" do
        ambassador = FactoryBot.create(:ambassador)
        FactoryBot.create_list(:ambassador_task_assignment, 2, :completed, ambassador: ambassador)
        expect(ambassador.percent_complete).to eq(1)
      end
    end
  end
end
