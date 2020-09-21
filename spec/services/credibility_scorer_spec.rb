require "rails_helper"

RSpec.describe CredibilityScorer do
  let(:subject) { described_class }
  let(:instance) { subject.new(bike) }
  let(:bike) { FactoryBot.create(:bike) }

  describe "all_badges" do
    it "is a one dimensional hash" do
      expect(CredibilityScorer.all_badges.is_a?(Hash)).to be_truthy
      expect(CredibilityScorer.all_badges.first).to eq([:created_at_point_of_sale, 100])
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
      let(:badge_array) { %i[user_ambassador created_at_point_of_sale] }
      it "returns the value" do
        expect(subject.permitted_badges_hash(badge_array)).to eq({created_at_point_of_sale: 100, user_ambassador: 50})
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
    context "with user_trusted_organization_member and creation_organization_trusted" do
      let(:badge_array) { %i[user_trusted_organization_member creation_organization_trusted] }
      it "it returns just creation_organization_trusted" do
        expect(subject.permitted_badges_array(badge_array)).to eq([:creation_organization_trusted])
        expect(subject.permitted_badges_hash(badge_array)).to eq({creation_organization_trusted: 30})
        expect(subject.badge_value(badge_array)).to eq(30)
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
        allow(instance).to receive(:badges) { %i[user_ambassador long_time_registration] }
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
      it "returns with created_at_point_of_sale" do
        expect(subject.creation_badges(bike_lightspeed_pos.creation_state)).to include(:created_at_point_of_sale)
        expect(subject.creation_badges(bike_ascend_pos.creation_state)).to match_array([:created_at_point_of_sale])
      end
    end
    context "with organization" do
      let!(:bike) { FactoryBot.create(:creation_organization_bike, organization: organization, created_at: created_at) }
      let(:created_at) { Time.current - 20.days }
      let(:organization) { FactoryBot.create(:organization, approved: true) } # Organizations are verified by default
      let(:creation_state) { bike.creation_state }
      it "returns created this month" do
        expect(creation_state).to be_present
        expect(subject.creation_badges(creation_state)).to eq([:created_this_month])
      end
      context "bike shop with does_not_need_pos" do
        let(:organization) { FactoryBot.create(:organization, kind: "bike_shop", pos_kind: "does_not_need_pos") }
        it "returns with trusted organization" do
          expect(subject.creation_badges(creation_state)).to match_array([:created_at_point_of_sale])
        end
      end
      context "paid organization" do
        let(:organization) { FactoryBot.create(:organization_with_organization_features) }
        it "returns with trusted organization" do
          expect(organization.is_paid).to be_truthy
          expect(subject.creation_badges(creation_state)).to match_array([:creation_organization_trusted, :created_this_month])
          # It doesn't return anything but created_at_point_of_sale
          creation_state.update(is_pos: true)
          expect(subject.creation_badges(creation_state)).to eq([:created_at_point_of_sale])
          expect(instance.badges).to eq([:created_at_point_of_sale])
          expect(instance.score).to eq 100
        end
      end
      context "deleted organization, long_time_registration" do
        let(:created_at) { Time.current - 366.days }
        it "returns with creation_organization_suspiscious" do
          organization.destroy
          expect(subject.creation_badges(creation_state)).to match_array([:creation_organization_suspicious, :long_time_registration])
        end
      end
      context "unapproved organization, 6 months ago" do
        let(:created_at) { Time.current - 6.months }
        let(:organization) { FactoryBot.create(:organization, approved: false) } # Organizations are verified by default
        it "returns with creation_organization_suspiscious" do
          expect(subject.creation_age_badge(creation_state)).to eq nil
          expect(subject.creation_badges(creation_state)).to match_array([:creation_organization_suspicious])
        end
      end
    end
    context "registered 2 years ago" do
      let(:creation_state) { FactoryBot.create(:creation_state, created_at: Time.current - 1.day - 2.years, bike: bike) }
      it "returns long_time_registration" do
        expect(subject.creation_age_badge(creation_state)).to eq :long_time_registration
        expect(subject.creation_badges(creation_state)).to eq([:long_time_registration])
        expect(instance.score).to eq(60)
      end
    end
  end

  describe "ownership_badges" do
    let!(:creation_state) { FactoryBot.create(:creation_state, bike: bike, created_at: ownership1.created_at, creator: ownership1.creator) }
    let!(:ownership1) { FactoryBot.create(:ownership_claimed, bike: bike, created_at: Time.current - 400.days, creator: bike.creator) }
    it "returns claimed" do
      bike.reload
      expect(subject.ownership_badges(bike)).to eq([:current_ownership_claimed])
      # Also, general badges returns long_time_registration
      expect(instance.badges).to match_array(%i[long_time_registration current_ownership_claimed])
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
        # Also, general badges returns long_time_registration
        expect(instance.badges).to match_array(%i[long_time_registration multiple_ownerships])
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
        expect(instance.badges).to eq([:long_time_registration, :multiple_ownerships, :current_ownership_claimed, :user_banned])
        expect(instance.score).to eq(0)
      end
    end
    describe "long_time_user" do
      let(:user) { FactoryBot.create(:user, created_at: Time.current - 3.years) }
      it "returns veteran" do
        expect(subject.bike_user_badges(bike)).to eq([:long_time_user])
        # Also, just test for the full thing, because curiosity
        expect(instance.badges).to eq([:long_time_registration, :current_ownership_claimed, :long_time_user])
      end
      context "veteran also ambassador" do
        let!(:membership) { FactoryBot.create(:membership_ambassador, user: user, created_at: Time.current - 1.hour) }
        it "returns ambassador" do
          expect(subject.bike_user_badges(bike)).to eq([:user_ambassador])
        end
      end
    end
    describe "user_has_bike_recovered user_sent_in_bike_tips user_supporter" do
      let(:recovered_bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed, user: user) }
      let(:stolen_record) { recovered_bike.current_stolen_record }
      let!(:theft_alert) { FactoryBot.create(:theft_alert, :paid, stolen_record: stolen_record, creator: user) }
      let!(:feedback) { FactoryBot.create(:feedback, kind: "tip_stolen_bike", user: user) }
      it "returns the bike_badges" do
        stolen_record.add_recovery_information(recovered_description: "I recovered it!")
        stolen_record.reload
        expect(stolen_record.recovered?).to be_truthy
        bike.reload
        expect(subject.bike_user_badges(bike)).to match_array(%i[user_has_bike_recovered user_sent_in_bike_tip user_supporter])
      end
    end
    describe "user_name_suspicious" do
      let(:user) { FactoryBot.create(:user, email: "something5150@yahoo.com") }
      it "returns user_name_suspicious" do
        expect(subject.bike_user_badges(bike)).to match_array([:user_handle_suspicious])
      end
      context "user is member of trusted organization, supporter" do
        let(:organization) { FactoryBot.create(:organization_with_organization_features) }
        let!(:membership) { FactoryBot.create(:membership_claimed, user: user, organization: organization) }
        let!(:payment) { FactoryBot.create(:payment, user: user) }
        it "returns just user_trusted_organization_member" do
          expect(user.organizations.pluck(:id)).to eq([organization.id])
          expect(subject.bike_user_badges(bike)).to match_array(%i[user_trusted_organization_member user_supporter])
        end
      end
      context "user_handle_suspicious, long_time_user & donation" do
        let(:user) { FactoryBot.create(:user, name: "shady", email: "bar@example.com") }
        let(:user2) { FactoryBot.create(:user, created_at: Time.current - 5.years) }
        let!(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, creator: user2, user: user) }
        let(:strava_file) { File.read(Rails.root.join("spec", "fixtures", "integration_data_strava.json")) }
        let(:info) { JSON.parse(strava_file) }
        let!(:integration) { FactoryBot.create(:integration, information: info) }
        it "returns all" do
          expect(user.integrations.pluck(:id)).to eq([integration.id])
          expect(subject.bike_user_badges(bike)).to match_array([:user_handle_suspicious, :long_time_user, :user_connected_to_strava])
        end
        context "ambassador" do
          let!(:membership) { FactoryBot.create(:membership_ambassador, user: user, created_at: Time.current - 1.hour) }
          it "returns ambassador" do
            expect(subject.bike_user_badges(bike)).to eq([:user_ambassador])
          end
        end
      end
    end
  end

  describe "organization_trusted?" do
    let(:organization) { FactoryBot.create(:organization, pos_kind: "does_not_need_pos") }
    it "is false" do
      expect(subject.organization_trusted?(organization)).to be_falsey
    end
    context "manual pos kind" do
      let(:organization1) { FactoryBot.create(:organization, manual_pos_kind: "does_not_need_pos") }
      let(:organization2) { FactoryBot.create(:organization, manual_pos_kind: "lightspeed_pos") }
      it "is truthy" do
        expect(subject.organization_trusted?(organization1)).to be_truthy
        expect(subject.organization_trusted?(organization2)).to be_truthy
      end
    end
  end

  describe "organization_suspicious?" do
    let(:organization) { FactoryBot.create(:organization) }
    it "is false" do
      expect(subject.organization_suspicious?(organization)).to be_falsey
    end
    context "not approved" do
      let(:organization) { FactoryBot.create(:organization, approved: false) }
      it "is true" do
        expect(subject.organization_suspicious?(organization)).to be_truthy
      end
    end
  end

  describe "suspiscious_handle?" do
    ["shady-p@yahoo.com", "bike thief", "hoogivzzafudge5150@hotmail.co", "mj", "fuckyou@stuff.com", "cunt-edu"].each do |str|
      it "is truthy for #{str}" do
        expect(subject.suspiscious_handle?(str)).to be_truthy
      end
    end
    # Things that might trip us up
    ["Baller**", "696969 party"].each do |str|
      it "is falsey for #{str}" do
        expect(subject.suspiscious_handle?(str)).to be_falsey
      end
    end
    context ".edu email address" do
      let(:edu_email1) { "ncp5150@ccc7.edu" }
      let(:edu_email2) { "shady@ccc7.edu" }
      let(:edu_email3) { "asshole@ccc7.edu" }
      let(:edu_email4) { "thief@ccc7.edu" }
      it "ignores .edu email addresses, except thief" do
        expect(subject.suspiscious_handle?(edu_email1)).to be_falsey
        expect(subject.suspiscious_handle?(edu_email2)).to be_falsey
        expect(subject.suspiscious_handle?(edu_email3)).to be_falsey
        expect(subject.suspiscious_handle?(edu_email4)).to be_truthy
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
      let(:bike) { FactoryBot.create(:bike, serial_number: "XXX222-xvbpererfa") }
      let!(:duplicate_bike_group) { FactoryBot.create(:duplicate_bike_group, bike1: bike) }
      let!(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, bike: bike) }
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
