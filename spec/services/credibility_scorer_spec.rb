require "rails_helper"

RSpec.describe CredibilityScorer do
  let(:subject) { described_class }
  let(:instance) { subject.new(bike) }
  let(:bike) { FactoryBot.create(:bike) }

  describe "all_badges" do
    it "is a one dimensional hash" do
      expect(CredibilityScorer.all_badges.is_a?(Hash)).to be_truthy
      expect(CredibilityScorer.all_badges.first).to eq([:pos_registration, 100])
    end
  end

  describe "badge_value" do
    it "returns the badge_value" do
      expect(subject.badge_value(%i[registered_this_month no_creator])).to eq(-20)
      expect(subject.badge_value([:registered_this_month])).to eq(-10)
      # Also, works without an array
      expect(subject.badge_value(:registered_this_month)).to eq(-10)
    end
    context "with less than 0" do
      it "returns the value" do
        expect(subject.badge_value(%i[banned registered_this_month])).to eq(-110)
      end
    end
    context "with over 100" do
      it "returns the value" do
        expect(subject.badge_value(%i[pos_registration ambassador])).to eq(150)
      end
    end
    context "with multiple of the same" do
      it "returns just one" do
        expect(subject.badge_value(%i[longtime_user ambassador ambassador ambassador])).to eq(60)
      end
    end
  end

  describe "bike badges and score" do
    context "stubbed" do
      it "returns min score if below" do
        allow(instance).to receive(:badges) { %i[banned no_creator] }
        expect(instance.score).to eq 0
      end
      it "returns max score if above" do
        allow(instance).to receive(:badges) { %i[ambassador registered_5_years_ago] }
        expect(instance.score).to eq 100
      end
    end
    xit "returns badges and score for a bike" do
      expect(instance.badges).to eq(%i[registered_this_month no_creator])
      expect(instance.score).to eq(-20)
    end
  end

  # describe "score" do
  #   it "is 50 (by default)" do
  #     expect(CredibilityScorer.score(Bike.new)).to eq 50
  #   end
  #   context "pos registration" do
  #     let!(:bike_lightspeed_pos) { FactoryBot.create(:bike_lightspeed_pos) }
  #     let!(:bike_ascend_pos) { FactoryBot.create(:bike_ascend_pos) }
  #     it "is 100" do
  #       expect(CredibilityScorer.score(bike_lightspeed_pos)).to eq 100
  #       expect(CredibilityScorer.score(bike_ascend_pos)).to eq 100
  #     end
  #   end
  #   context "user has claimed" do
  #     let(:user) { FactoryBot.create(:user_confirmed) }
  #     let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: user) }
  #     it "is 60" do
  #       bike.reload
  #       expect(CredibilityScorer.score(bike)).to eq 60
  #     end
  #     context "user banned" do
  #       let(:user) { FactoryBot.create(:user, banned: true) }
  #       it "is 0" do
  #         expect(CredibilityScorer.score(bike)).to eq 0
  #       end
  #     end
  #     context "created by deleted user" do
  #       let(:user) { FactoryBot.create(:user) }
  #       it "is 40" do
  #         user.destroy
  #         expect(CredibilityScorer.score(bike)).to eq 40
  #       end
  #     end
  #   end
  #   context "1 ownership with a banned user" do
  #     let(:user) { FactoryBot.create(:user, banned: true) }
  #     let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
  #     let!(:ownership) { FactoryBot.create(:ownership, bike: bike, user: user, created_at: Time.current - 2.years) }
  #     it "returns 0" do
  #       expect(bike.credibility_score).to eq 0
  #     end
  #   end
  #   context "created by organization" do
  #     let(:bike) { FactoryBot.create(:bike_organized) }
  #     it "is 60" do
  #       bike.reload
  #       expect(bike.user).to be_blank
  #       expect(bike.creation_organization).to be_present
  #       expect(bike.credibility_score).to eq 60
  #     end
  #     context "organization deleted" do
  #       it "is 40" do
  #         bike.creation_organization.destroy
  #         bike.reload
  #         expect(bike.credibility_score).to eq 40
  #       end
  #     end
  #   end
  # end

  # describe "user_score" do
  #   let(:user) { FactoryBot.create(:user) }
  #   it "is 0" do
  #     expect(CredibilityScorer.user_score(user)).to eq 0
  #   end
  #   context "user ambassador" do
  #     let(:organization) { FactoryBot.create(:organization_ambassador)}
  #     let(:user) { FactoryBot.create(:organization_member, organization: organization)}
  #     it "is 50" do
  #       expect(CredibilityScorer.user_score(user)).to eq 50
  #     end
  #   end
  #   context "user_banned" do
  #     let(:user) { FactoryBot.create(:user, banned: true) }
  #     it "is -1000" do
  #       expect(user.banned).to be_truthy
  #       expect(CredibilityScorer.user_score(user)).to eq(-1000)
  #     end
  #   end
  # end

  # describe "creation_organization_modifier" do
  #   let(:organization) { FactoryBot.create(:organization) }
  #   let(:bike) { FactoryBot.create(:bike_organized, organization: organization) }
  #   it "is 10" do
  #     expect(organization.approved).to be_truthy
  #     expect(CredibilityScorer.creation_organization_score(bike)).to eq 10
  #   end
  #   context "organization not approved" do
  #     let(:organization) { FactoryBot.create(:organization, approved: false) }
  #     it "is 0" do
  #       expect(organization.approved).to be_falsey
  #       expect(CredibilityScorer.creation_organization_score(bike)).to eq(-10)
  #     end
  #   end
  #   context "ambassador organization" do
  #     let(:organization) { FactoryBot.create(:organization_ambassador) }
  #     it "is 50" do
  #       expect(CredibilityScorer.creation_organization_score(bike)).to eq 50
  #     end
  #   end
  # end

  # describe "current_owner_score" do
  #   it "is 0" do
  #     expect(CredibilityScorer.current_owner_score(nil)).to eq 0
  #   end
  #   context "user_confirmed" do
  #     let(:user) { FactoryBot.create(:user_confirmed) }
  #     it "is 10" do
  #       expect(CredibilityScorer.current_owner_score(user)).to eq 10
  #     end
  #   end
  #   context "user is member of organization" do
  #     let(:user) { FactoryBot.create(:organization_member, organization: organization) }
  #     let(:organization) { FactoryBot.create(:organization) }
  #     it "is 10" do
  #       expect(CredibilityScorer.current_owner_score(user)).to eq 10
  #     end
  #     context "organization deleted" do
  #       it "is 0" do
  #         organization.destroy
  #         expect(CredibilityScorer.current_owner_score(user)).to eq 0
  #       end
  #     end
  #     context "ambassador organization" do
  #       let(:organization) { FactoryBot.create(:organization_ambassador) }
  #       it "is 60" do
  #         expect(CredibilityScorer.current_owner_score(user)).to eq 60
  #       end
  #     end
  #   end
  # end
end
