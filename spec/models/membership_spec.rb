require "spec_helper"

describe Membership do
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
