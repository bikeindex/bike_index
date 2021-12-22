require "rails_helper"

RSpec.describe Ownership, type: :model do
  describe "factories" do
    let(:ownership) { FactoryBot.create(:ownership) }
    it "creates" do
      expect(ownership).to be_valid
    end
    describe "bike with_ownership_claimed" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
      it "creates" do
        expect(bike.reload.ownerships.count).to eq 1
        expect(Ownership.count).to eq 1
        ownership = bike.current_ownership
        expect(ownership.claimed?).to be_truthy
        expect(ownership.organization_id).to be_blank
        expect(ownership.owner_email).to eq bike.owner_email
        expect(ownership.creator).to eq bike.creator
      end
      context "bike_organized" do
        let(:time) { Time.current - 5.weeks }
        let(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, can_edit_claimed: false, created_at: time) }
        it "creates" do
          expect(bike.reload.created_at).to be_within(1).of time
          expect(bike.ownerships.count).to eq 1
          ownership = bike.current_ownership
          expect(ownership.claimed?).to be_truthy
          expect(ownership.organization_id).to eq bike.creation_organization_id
          expect(ownership.owner_email).to eq bike.owner_email
          expect(ownership.creator).to eq bike.creator
          expect(ownership.created_at).to be_within(1).of time
          expect(bike.bike_organizations.count).to eq 1
          bike_organization = bike.bike_organizations.first
          expect(bike_organization.can_edit_claimed).to be_falsey
          expect(bike_organization.created_at).to be_within(1).of time
          expect(bike_organization.organization_id).to eq bike.creation_organization_id
        end
      end
    end
  end

  describe "set_calculated_attributes" do
    it "removes leading and trailing whitespace and downcase email" do
      ownership = Ownership.new(owner_email: "   SomE@dd.com ")
      ownership.set_calculated_attributes
      expect(ownership.owner_email).to eq("some@dd.com")
      expect(ownership.claimed?).to be_falsey
      expect(ownership.token).to be_present
    end
  end

  describe "send_notification_and_update_other_ownerships" do
    let(:ownership1) { FactoryBot.create(:ownership) }
    let(:bike) { ownership1.bike }
    let!(:ownership2) { FactoryBot.create(:ownership, bike: bike) }
    it "marks existing ownerships as not current" do
      ownership2.reload
      Sidekiq::Worker.clear_all
      expect {
        bike.ownerships.create(creator: ownership2.creator,
          owner_email: "s@s.com")
      }.to change(EmailOwnershipInvitationWorker.jobs, :size).by(1)
      expect(bike.ownerships.count).to eq 3
      expect(bike.reload.send("calculated_current_ownership")&.id).to be > ownership2.id
      expect(ownership1.reload.current).to be_falsey
      expect(ownership2.reload.current).to be_falsey
    end
  end

  describe "phone registration" do
    let(:bike) { FactoryBot.create(:bike, :phone_registration) }
    it "adds as a phone registration" do
      expect(bike.phone).to be_present
      ownership = bike.ownerships.new
      expect(ownership).to be_valid
      expect(ownership.save).to be_truthy
      expect(ownership.calculated_send_email).to be_falsey
      expect(ownership.phone_registration?).to be_truthy
      expect(ownership.owner_email).to eq bike.phone
    end
  end

  describe "claim_message" do
    let(:email) { "joe@example.com" }
    let(:ownership) { Ownership.new(current: true) }
    it "returns new_registration" do
      expect(ownership.new_registration?).to be_truthy
      expect(ownership.claim_message).to eq "new_registration"
    end
    context "transferred ownership" do
      let(:bike) { FactoryBot.create(:bike_organized, owner_email: email) }
      let!(:ownership1) { bike.ownerships.first }
      let(:ownership2) { FactoryBot.create(:ownership, bike: bike, creator: bike.creator, owner_email: email) }
      it "returns transferred_ownership" do
        ownership2.reload
        ownership1.reload
        expect(ownership1.current?).to be_falsey
        expect(ownership1.claim_message).to be_blank
        expect(ownership1.calculated_organization&.id).to eq bike.organizations.first.id
        expect(ownership1.first?).to be_truthy
        expect(ownership1.previous_ownership_id).to be_blank
        expect(ownership2.current?).to be_truthy
        expect(ownership2.first?).to be_falsey
        expect(ownership2.second?).to be_truthy
        expect(ownership2.calculated_organization&.id).to be_blank
        expect(ownership2.prior_ownerships.pluck(:id)).to eq([ownership1.id])
        expect(ownership2.new_registration?).to be_falsey
        expect(ownership2.previous_ownership_id).to eq ownership1.id
        expect(ownership2.claim_message).to eq "transferred_registration"
      end
    end
    context "organization" do
      let(:organization) { FactoryBot.create(:organization, :with_auto_user) }
      let(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization, owner_email: email, creator: organization.auto_user) }
      let(:ownership) { bike.ownerships.first }
      it "returns new_registration" do
        ownership.reload
        expect(ownership.calculated_organization).to eq organization
        expect(ownership.user).to be_blank
        expect(ownership.new_registration?).to be_truthy
        expect(ownership.claim_message).to eq "new_registration"
      end
      context "transfer from organization to new user" do
        let(:membership) { FactoryBot.create(:membership, organization: organization) }
        let(:ownership2) { FactoryBot.build(:ownership, bike: bike, creator: bike.creator, owner_email: email) }
        it "returns new_registration" do
          # Before save, still works
          expect(ownership2.current).to be_truthy
          expect(ownership2.prior_ownerships.pluck(:id)).to eq([ownership.id])
          expect(ownership2.first?).to be_falsey
          expect(ownership2.second?).to be_truthy
          ownership2.save
          ownership2.reload
          ownership.reload
          expect(ownership.current?).to be_falsey
          expect(ownership.calculated_organization&.id).to eq organization.id
          expect(ownership.first?).to be_truthy
          expect(ownership.previous_ownership_id).to be_blank
          expect(ownership2.current?).to be_truthy
          expect(ownership2.first?).to be_falsey
          expect(ownership2.second?).to be_truthy
          expect(ownership2.calculated_organization&.id).to eq organization.id
          expect(ownership2.prior_ownerships.pluck(:id)).to eq([ownership.id])
          expect(ownership2.previous_ownership_id).to eq ownership.id
          # Registrations that were initially from an organization member, then transferred outside of the organization,
          # count as "new" - because some organizations pre-register bikes
          expect(ownership2.new_registration?).to be_truthy
          expect(ownership2.claim_message).to eq "new_registration"
        end
      end
    end
    context "claimed" do
      let(:ownership) { Ownership.new(current: true, claimed: true) }
      it "returns nil" do
        expect(ownership.claim_message).to be_blank
      end
    end
    context "existing user" do
      let(:ownership) { Ownership.new(current: true, user: User.new(confirmed: true)) }
      it "returns new_registration" do
        expect(ownership.claimed?).to be_falsey
        expect(ownership.new_registration?).to be_truthy
        expect(ownership.claim_message).to be_blank
      end
    end
  end

  describe "validate owner_email format" do
    it "disallows owner_emails without an @ sign" do
      ownership = FactoryBot.build_stubbed(:ownership, owner_email: "n/a")
      expect(ownership).to_not be_valid
      expect(ownership.errors.full_messages).to eq(["Owner email invalid format"])
    end

    it "disallows owner_emails without a tld" do
      ownership = FactoryBot.build_stubbed(:ownership, owner_email: "name@email")
      expect(ownership).to_not be_valid
      expect(ownership.errors.full_messages).to eq(["Owner email invalid format"])
    end

    it "disallows owner_emails without a mailbox" do
      ownership = FactoryBot.build_stubbed(:ownership, owner_email: "@email.com")
      expect(ownership).to_not be_valid
      expect(ownership.errors.full_messages).to eq(["Owner email invalid format"])
    end

    it "allows owner_emails with valid modifications" do
      ownership = FactoryBot.build_stubbed(:ownership, owner_email: "name.1@email.com")
      expect(ownership).to be_valid
      ownership = FactoryBot.build_stubbed(:ownership, owner_email: "name+two@email.com")
      expect(ownership).to be_valid
    end

    it "allows phone" do
      ownership = FactoryBot.build_stubbed(:ownership, owner_email: "7654321111", is_phone: true)
      expect(ownership).to be_valid
    end
  end

  describe "mark_claimed" do
    it "doesn't update if user isn't present" do
      ownership = FactoryBot.create(:ownership)
      ownership.mark_claimed
      ownership.reload
      expect(ownership.claimed?).to be_truthy
      expect(ownership.claimed_at).to be_present
    end
    context "factory ownership_claimed" do
      let(:claimed_at) { Time.current - 2.weeks }
      let!(:ownership) { FactoryBot.create(:ownership_claimed, claimed_at: claimed_at) }
      it "is claimed" do
        expect(ownership.claimed?).to be_truthy
        ownership.mark_claimed
        ownership.reload
        expect(ownership.claimed?).to be_truthy
        expect(ownership.claimed_at).to be_within(1).of claimed_at
        ownership.mark_claimed
      end
    end
  end

  describe "owner" do
    it "returns the current owner if the ownership is claimed" do
      user = FactoryBot.create(:user_confirmed)
      ownership = Ownership.new
      allow(ownership).to receive(:claimed).and_return(true)
      allow(ownership).to receive(:user).and_return(user)
      expect(ownership.owner).to eq(user)
    end

    it "returns the creator if it isn't claimed" do
      user = FactoryBot.create(:user_confirmed)
      ownership = Ownership.new
      allow(ownership).to receive(:claimed).and_return(false)
      allow(ownership).to receive(:creator).and_return(user)
      expect(ownership.owner).to eq(user)
    end

    it "returns auto user if creator is deleted" do
      user = FactoryBot.create(:user_confirmed, email: ENV["AUTO_ORG_MEMBER"])
      ownership = Ownership.new
      expect(ownership.owner).to eq(user)
    end
  end

  describe "claimable_by?" do
    let(:user) { FactoryBot.create(:user_confirmed) }
    it "true if user email matches" do
      ownership = Ownership.new(owner_email: " #{user.email.upcase}")
      expect(ownership.claimable_by?(user)).to be_truthy
    end
    it "true if user matches" do
      ownership = Ownership.new(user_id: user.id)
      expect(ownership.claimable_by?(user)).to be_truthy
    end
    it "false if it can't be claimed by user" do
      ownership = Ownership.new(owner_email: "fake#{user.email.titleize}")
      expect(ownership.claimable_by?(user)).to be_falsey
    end
  end

  describe "calculated_send_email" do
    let(:bike) { FactoryBot.create(:bike) }
    let(:ownership) { Ownership.new(bike: bike) }
    it "is true" do
      expect(ownership.send(:spam_risky_email?)).to be_falsey
      expect(ownership.calculated_send_email).to be_truthy
    end
    context "send email is false" do
      let(:ownership) { Ownership.new(send_email: false, bike: bike) }
      it "is false" do
        expect(ownership.calculated_send_email).to be_falsey
      end
    end
    context "example bike" do
      let(:bike) { Bike.new(example: true) }
      let(:ownership) { Ownership.new(bike: bike) }
      it "is false" do
        expect(ownership.calculated_send_email).to be_falsey
      end
    end
    context "organization with organization feature of skip_ownership_email" do
      let!(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["skip_ownership_email"]) }
      let!(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization) }
      let(:ownership) { bike.ownerships.first }
      it "returns false" do
        # There was some trouble with CI on this, so now we're just updating a bunch
        ownership.update(updated_at: Time.current)
        expect(organization.enabled?("skip_ownership_email")).to be_truthy
        expect(ownership.first?).to be_truthy
        expect(ownership.calculated_send_email).to be_falsey
        ownership2 = FactoryBot.create(:ownership, bike: bike, created_at: Time.current)
        ownership2.update(updated_at: Time.current)
        ownership2.reload
        expect(ownership2.calculated_organization).to be_blank
        expect(ownership2.calculated_send_email).to be_truthy
      end
    end
  end

  describe "spam_risky_email?" do
    # hotmail and yahoo have been delaying our emails. In an effort to ensure delivery of really important emails (e.g. password resets)
    # skip sending ownership invitations for POS registrations, just in case
    let(:bike) { FactoryBot.create(:bike, owner_email: email) }
    let(:ownership) { Ownership.new(bike: bike, owner_email: email, pos_kind: pos_kind) }
    let(:pos_kind) { "lightspeed_pos" }
    context "gmail email" do
      let(:email) { "test@gmail.com" }
      it "false, calculated_send_email: true" do
        expect(ownership.send(:spam_risky_email?)).to be_falsey
        expect(ownership.calculated_send_email).to be_truthy
      end
    end
    context "yahoo email" do
      let(:email) { "test@yahoo.com" }
      it "does not send" do
        expect(ownership.send(:spam_risky_email?)).to be_truthy
        expect(ownership.calculated_send_email).to be_falsey
      end
      context "yahoo.co" do
        let(:email) { "example@yahoo.co" } # I don't know if these are typos or it's separate, but skip it nonetheless
        it "does not send" do
          expect(ownership.send(:spam_risky_email?)).to be_truthy
          expect(ownership.calculated_send_email).to be_falsey
        end
      end
      context "not pos registration" do
        let(:pos_kind) { "does_not_need_pos" }
        it "sends" do
          expect(ownership.send(:spam_risky_email?)).to be_falsey
          expect(ownership.calculated_send_email).to be_truthy
        end
      end
    end
    context "hotmail email" do
      let(:email) { "test@hotmail.com" }
      let(:pos_kind) { "ascend_pos" }
      it "does not send" do
        expect(ownership.send(:spam_risky_email?)).to be_truthy
        expect(ownership.calculated_send_email).to be_falsey
      end
      context "not pos registration" do
        let(:pos_kind) { "no_pos" }
        it "sends" do
          expect(bike).to be_present
          expect(ownership.bike).to be_present
          expect(ownership.bike.example?).to be_falsey
          expect(ownership.phone_registration?).to be_falsey
          expect(ownership.send(:spam_risky_email?)).to be_falsey
          expect(ownership.calculated_send_email).to be_truthy
        end
      end
    end
  end

  describe "calculated_organization_pre_registration?" do
    let(:ownership) { Ownership.new }
    it "is false" do
      expect(ownership.send("calculated_organization_pre_registration?")).to be_falsey
    end
    context "organization registration" do
      let(:organization) { FactoryBot.create(:organization_with_auto_user) }
      let(:creator) { FactoryBot.create(:organization_member, organization: organization) }
      let(:owner_email) { creator.email }
      let(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization, creator: creator, owner_email: owner_email) }
      let(:ownership) { bike.ownerships.first }
      it "is falsey" do
        ownership.reload
        expect(ownership.organization_id).to eq organization.id
        expect(ownership.creator_id).to_not eq organization.auto_user_id
        expect(ownership.self_made?).to be_truthy
        expect(ownership.claimed?).to be_truthy
        expect(ownership.send("calculated_organization_pre_registration?")).to be_falsey
      end
      context "auto user" do
        let(:creator) { organization.auto_user }
        before { creator.confirm(creator.confirmation_token) }
        it "is truthy" do
          expect(User.fuzzy_email_find(owner_email)&.id).to eq creator.id
          ownership.reload
          expect(ownership.organization_id).to eq organization.id
          expect(ownership.creator_id).to eq organization.auto_user_id
          expect(ownership.user_id).to eq creator.id
          expect(ownership.self_made?).to be_truthy
          expect(ownership.claimed?).to be_truthy
          expect(ownership.send("calculated_organization_pre_registration?")).to be_truthy
        end
        context "not self made" do
          let(:member) { FactoryBot.create(:organization_member, organization: organization) }
          let(:owner_email) { member.email }
          it "is falsey" do
            ownership.reload
            expect(User.fuzzy_email_find(owner_email)&.id).to_not eq creator.id
            expect(ownership.creator_id).to eq organization.auto_user_id
            expect(ownership.user_id).to_not eq creator.id
            expect(ownership.self_made?).to be_falsey
            expect(ownership.claimed?).to be_falsey
            expect(ownership.send("calculated_organization_pre_registration?")).to be_falsey
          end
        end
        context "not first" do
          let(:ownership2) { FactoryBot.create(:ownership, bike: bike, organization: organization, creator: creator, owner_email: owner_email) }
          it "is falsey" do
            ownership.reload
            expect(ownership.send("calculated_organization_pre_registration?")).to be_truthy
            expect(User.fuzzy_email_find(owner_email)&.id).to eq creator.id
            ownership2.reload
            expect(ownership2.prior_ownerships.pluck(:id)).to eq([ownership.id])
            expect(ownership2.previous_ownership_id).to eq ownership.id
            expect(ownership2.organization_id).to eq organization.id
            expect(ownership2.creator_id).to eq organization.auto_user_id
            expect(ownership2.user_id).to eq creator.id
            expect(ownership2.self_made?).to be_truthy
            expect(ownership2.claimed?).to be_truthy
            expect(ownership2.send("calculated_organization_pre_registration?")).to be_truthy
            bike.reload
            expect(bike.current_ownership&.id).to eq ownership2.id
          end
        end
      end
    end
  end

  describe "creation_description" do
    let(:ownership) { Ownership.new(organization_id: 1, creator_id: 1) }
    it "returns nil" do
      expect(ownership.creation_description).to be_nil
    end
    context "bulk" do
      let(:ownership) { Ownership.new(bulk_import_id: 12, origin: "api_v2") }
      it "returns bulk reg" do
        expect(ownership.creation_description).to eq "bulk import"
        expect(ownership.pos?).to be_falsey
      end
    end
    context "pos" do
      let(:ownership) { Ownership.new(pos_kind: "lightspeed_pos", origin: "embed_extended") }
      before { ownership.set_calculated_attributes }
      it "returns pos reg" do
        expect(ownership.creation_description).to eq "Lightspeed"
      end
      context "ascend" do
        let(:bulk_import) { BulkImport.new(kind: "ascend") }
        let(:ownership) { Ownership.new(pos_kind: "ascend_pos", bulk_import: bulk_import) }
        it "returns pos reg" do
          expect(ownership.creation_description).to eq "Ascend"
        end
      end
    end
    context "web" do
      let(:ownership) { Ownership.new(origin: "web") }
      it "returns web" do
        expect(ownership.creation_description).to eq "web"
      end
    end
    context "embed_extended" do
      let(:ownership) { Ownership.new(origin: "embed_extended") }
      it "returns org internal" do
        expect(ownership.creation_description).to eq "org reg"
      end
    end
    context "organization_form" do
      let(:ownership) { Ownership.new(origin: "organization_form") }
      it "returns org internal" do
        expect(ownership.creation_description).to eq "org reg"
      end
    end
    context "embed_partial" do
      let(:ownership) { Ownership.new(origin: "embed_partial") }
      it "returns landing page" do
        expect(ownership.creation_description).to eq "landing page"
      end
    end
  end
end
