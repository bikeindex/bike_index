require "rails_helper"

RSpec.describe CredibilityScorer do
  let(:subject) { described_class }
  let(:instance) { subject.new(bike) }
  let(:bike) { FactoryBot.create(:bike) }

  describe "all_badges" do
    it "is a one dimensional hash" do
      expect(CredibilityScorer.all_badges.is_a?(Hash)).to be_truthy
      expect(CredibilityScorer.all_badges.first).to eq([:created_by_point_of_sale, 100])
    end
  end

  describe "badge_value" do
    it "returns the badge_value" do
      expect(subject.badge_value(%i[created_this_month no_creator])).to eq(-20)
      expect(subject.badge_value([:created_this_month])).to eq(-10)
      # Also, works without an array
      expect(subject.badge_value(:created_this_month)).to eq(-10)
    end
    context "with less than 0" do
      it "returns the value" do
        expect(subject.badge_value(%i[user_banned created_this_month])).to eq(-210)
      end
    end
    context "with over 100" do
      let(:badge_array) { %i[user_ambassador created_by_point_of_sale] }
      it "returns the value" do
        expect(subject.permitted_badges_hash(badge_array)).to eq({created_by_point_of_sale: 100, user_ambassador: 50})
        expect(subject.badge_value(badge_array)).to eq(150)
      end
    end
    context "with multiple of the same" do
      let(:badge_array) { %i[has_bike_sticker user_ambassador user_ambassador user_ambassador] }
      it "returns just one" do
        expect(subject.permitted_badges_hash(badge_array)).to eq({has_bike_sticker: 10, user_ambassador: 50})
        expect(subject.badge_value(badge_array)).to eq(60)
      end
    end
    context "with user_ambassador and creation_organization_trusted" do
      let(:badge_array) { %i[user_ambassador creation_organization_trusted] }
      it "it returns just user_ambassador" do
        expect(subject.permitted_badges_array(badge_array)).to eq([:user_ambassador])
        expect(subject.permitted_badges_hash(badge_array)).to eq({user_ambassador: 50})
        expect(subject.badge_value(badge_array)).to eq(50)
      end
    end
  end

  describe "bike badges and score" do
    context "stubbed" do
      it "returns min score if below" do
        allow(instance).to receive(:badges) { %i[user_banned no_creator] }
        expect(instance.score).to eq 0
      end
      it "returns max score if above" do
        allow(instance).to receive(:badges) { %i[user_ambassador created_5_years_ago] }
        expect(instance.score).to eq 100
      end
    end
    it "returns badges and score for a bike" do
      expect(instance.badges).to eq(%i[])
      expect(instance.score).to eq(50)
    end
  end

  describe "creation_badges" do
    context "pos registrations" do
      let!(:bike_lightspeed_pos) { FactoryBot.create(:bike_lightspeed_pos) }
      let!(:bike_ascend_pos) { FactoryBot.create(:bike_ascend_pos) }
      it "returns with created_by_point_of_sale" do
        expect(subject.creation_badges(bike_lightspeed_pos.creation_state)).to include(:created_by_point_of_sale)
        expect(subject.creation_badges(bike_ascend_pos.creation_state)).to match_array([:created_by_point_of_sale])
      end
    end
    context "with organization" do
      let!(:bike) { FactoryBot.create(:creation_organization_bike, organization: organization) }
      let(:organization) { FactoryBot.create(:organization, approved: true) } # Organizations are verified by default
      let(:creation_state) { bike.creation_state }
      it "returns created this month" do
        expect(creation_state).to be_present
        expect(subject.creation_badges(creation_state)).to eq([:created_this_month])
      end
      context "bike shop with does_not_need_pos" do
        let(:organization) { FactoryBot.create(:organization, kind: "bike_shop", pos_kind: "does_not_need_pos") }
        it "returns with trusted organization" do
          expect(subject.creation_badges(creation_state)).to match_array([:creation_organization_trusted, :created_this_month])
        end
      end
      context "paid organization" do
        let(:organization) { FactoryBot.create(:organization_with_paid_features) }
        it "returns with trusted organization" do
          expect(organization.is_paid).to be_truthy
          expect(subject.creation_badges(creation_state)).to match_array([:creation_organization_trusted, :created_this_month])
          # It doesn't return anything but created_by_point_of_sale
          creation_state.update(is_pos: true)
          expect(subject.creation_badges(creation_state)).to eq([:created_by_point_of_sale])
          expect(instance.badges).to eq([:created_by_point_of_sale])
          expect(instance.score).to eq 100
        end
      end
      context "deleted organization, created_1_year_ago" do
        let!(:bike) { FactoryBot.create(:creation_organization_bike, organization: organization, created_at: Time.current - 366.days) }
        let(:organization) { FactoryBot.create(:organization, approved: false) } # Organizations are verified by default
        it "returns with creation_organization_suspiscious" do
          expect(subject.creation_badges(creation_state)).to match_array([:creation_organization_suspicious, :created_1_year_ago])
        end
      end
    end
    context "registered 6 months ago" do
      let(:creation_state) { FactoryBot.create(:creation_state, created_at: Time.current - 6.months, bike: bike) }
      it "returns nothing" do
        expect(subject.creation_age_badge(creation_state)).to eq nil
        expect(subject.creation_badges(creation_state)).to eq([])
      end
    end
    context "registered 2 years ago" do
      let(:creation_state) { FactoryBot.create(:creation_state, created_at: Time.current - 1.day - 2.years, bike: bike) }
      it "returns created_2_years_ago" do
        expect(subject.creation_age_badge(creation_state)).to eq :created_2_years_ago
        expect(subject.creation_badges(creation_state)).to eq([:created_2_years_ago])
        expect(instance.score).to eq(70)
      end
    end
    context "registered 4 years ago" do
      let(:creation_state) { FactoryBot.create(:creation_state, created_at: Time.current - 4.years, bike: bike) }
      it "returns created_3_years_ago" do
        expect(subject.creation_badges(creation_state)).to eq([:created_3_years_ago])
      end
    end
    context "registered 7 years ago" do
      let(:creation_state) { FactoryBot.create(:creation_state, created_at: Time.current - 5.years, bike: bike) }
      it "returns created_5_years_ago" do
        expect(subject.creation_badges(creation_state)).to eq([:created_5_years_ago])
        expect(instance.score).to eq(90)
      end
    end
  end

  describe "ownership_badges" do
    let!(:creation_state) { FactoryBot.create(:creation_state, bike: bike, created_at: ownership1.created_at, creator: ownership1.creator) }
    let!(:ownership1) { FactoryBot.create(:ownership_claimed, bike: bike, created_at: Time.current - 400.days, creator: bike.creator) }
    it "returns claimed" do
      bike.reload
      expect(subject.ownership_badges(bike)).to eq([:current_ownership_claimed])
      # Also, general badges returns created_1_year_ago
      expect(instance.badges).to match_array(%i[created_1_year_ago current_ownership_claimed])
    end
    context "multiple ownerships" do
      let!(:ownership2) { FactoryBot.create(:ownership, bike: bike) }
      it "returns" do
        bike.reload
        ownership1.reload
        ownership2.reload
        expect(bike.current_ownership).to eq ownership2
        expect(ownership1.current?).to be_falsey
        expect(subject.ownership_badges(bike)).to eq([:multiple_ownerships])
        # Also, general badges returns created_1_year_ago
        expect(instance.badges).to match_array(%i[created_1_year_ago multiple_ownerships])
      end
    end
  end

  describe "bike_user_badges" do
    let!(:bike) { FactoryBot.create(:bike, creator: user) }
    let(:ownership1) { FactoryBot.create(:ownership_claimed, bike: bike, created_at: Time.current - 6.years, creator: bike.creator) }
    let!(:creation_state) { FactoryBot.create(:creation_state, creator: user, bike: bike, created_at: ownership1.created_at) }
    let(:user) { FactoryBot.create(:user) }
    let(:banned_user) { FactoryBot.create(:user, banned: true) }
    it "returns []" do
      expect(subject.bike_user_badges(bike)).to eq([])
    end
    context "creator banned" do
      let(:user) { banned_user }
      it "returns banned" do
        expect(bike.creator.banned).to be_truthy
        expect(subject.bike_user_badges(bike)).to eq([:user_banned])
      end
    end
    context "previous owner banned" do
      let(:user2) { FactoryBot.create(:user, created_at: Time.current - 5.years) }
      let(:ambassador) { FactoryBot.create(:user) }
      let!(:membership) { FactoryBot.create(:membership_ambassador, user: ambassador, created_at: Time.current - 1.hour) }
      let!(:ownership2) { FactoryBot.create(:ownership_claimed, bike: bike, created_at: Time.current - 4.years, creator: banned_user, user: user2) }
      let!(:ownership3) { FactoryBot.create(:ownership_claimed, bike: bike, created_at: Time.current - 2.years, creator: user2, user: ambassador) }
      it "returns banned" do
        bike.reload
        expect(bike.current_ownership).to eq ownership3
        expect(bike.user&.id).to eq ambassador.id
        # It ignores that there is an ambassador in there
        expect(subject.bike_user_badges(bike)).to eq([:user_banned])
        # Also, just test for the full thing, because curiosity
        expect(instance.badges).to eq([:created_5_years_ago, :multiple_ownerships, :current_ownership_claimed, :user_banned])
        expect(instance.score).to eq(0)
      end
    end
    context "veteran user" do
      let(:user) { FactoryBot.create(:user, created_at: Time.current - 3.years) }
      it "returns veteran" do
        expect(subject.bike_user_badges(bike)).to eq([:user_veteran])
        # Also, just test for the full thing, because curiosity
        expect(instance.badges).to eq([:created_5_years_ago, :current_ownership_claimed, :user_veteran])
      end
      context "veteran also ambassador" do
        let!(:membership) { FactoryBot.create(:membership_ambassador, user: user, created_at: Time.current - 1.hour) }
        it "returns ambassador" do
          expect(subject.bike_user_badges(bike)).to eq([:user_ambassador])
        end
      end
    end
  end

  describe "bike_badges" do
    it "is empty" do
      expect(subject.bike_badges(bike)).to eq([])
    end
    context "missing_serial" do
      let(:bike) { FactoryBot.create(:bike, serial_number: "probably has one don't know it") }
      it "returns" do
        bike.reload
        expect(bike.serial_unknown?).to be_truthy
        expect(bike.made_without_serial?).to be_falsey
        expect(subject.bike_badges(bike)).to eq([:serial_missing])
        expect(instance.badges).to eq([:serial_missing])
        expect(instance.score).to eq(40)
      end
    end
    context "made without serial" do
      let(:bike) { FactoryBot.create(:bike, serial_number: "made_without_serial") }
      it "does not include missing_serial" do
        bike.reload
        expect(bike.duplicate_bikes.count).to eq 0
        expect(bike.serial_unknown?).to be_falsey
        expect(bike.made_without_serial?).to be_truthy
        expect(subject.bike_badges(bike)).to eq([])
      end
    end
    context "bike sticker, photo and duplicate serial" do
      let(:bike) { FactoryBot.create(:bike, serial_number: "XXX222-xvbpererfa")}
      let!(:duplicate_bike_group) { FactoryBot.create(:duplicate_bike_group, bike1: bike)}
      let!(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, bike: bike)}
      let!(:public_image) { FactoryBot.create(:public_image, imageable: bike) }
      it "returns" do
        bike.reload
        expect(bike.duplicate_bikes.count).to be > 0
        expect(subject.bike_badges(bike)).to match_array(%i[serial_duplicated has_photos has_bike_sticker])
        expect(instance.badges).to match_array(%i[has_photos has_bike_sticker serial_duplicated])
        expect(instance.score).to eq(50)
      end
    end
  end
end
