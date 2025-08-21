# == Schema Information
#
# Table name: ownerships
#
#  id                            :integer          not null, primary key
#  claimed                       :boolean          default(FALSE)
#  claimed_at                    :datetime
#  current                       :boolean          default(FALSE)
#  example                       :boolean          default(FALSE), not null
#  is_new                        :boolean          default(FALSE)
#  is_phone                      :boolean          default(FALSE)
#  organization_pre_registration :boolean          default(FALSE)
#  origin                        :integer
#  owner_email                   :string(255)
#  owner_name                    :string
#  pos_kind                      :integer
#  registration_info             :jsonb
#  skip_email                    :boolean          default(FALSE)
#  status                        :integer
#  token                         :text
#  user_hidden                   :boolean          default(FALSE), not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  bike_id                       :integer
#  bulk_import_id                :bigint
#  creator_id                    :integer
#  impound_record_id             :bigint
#  organization_id               :bigint
#  previous_ownership_id         :bigint
#  user_id                       :integer
#
# Indexes
#
#  index_ownerships_on_bike_id            (bike_id)
#  index_ownerships_on_bulk_import_id     (bulk_import_id)
#  index_ownerships_on_creator_id         (creator_id)
#  index_ownerships_on_impound_record_id  (impound_record_id)
#  index_ownerships_on_organization_id    (organization_id)
#  index_ownerships_on_user_id            (user_id)
#
require "rails_helper"

RSpec.describe Ownership, type: :model do
  it_behaves_like "registration_infoable"

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
      Sidekiq::Job.clear_all
      expect {
        bike.ownerships.create(creator: ownership2.creator,
          owner_email: "s@s.com")
      }.to change(Email::OwnershipInvitationJob.jobs, :size).by(1)
      expect(bike.ownerships.count).to eq 3
      expect(bike.reload.send(:calculated_current_ownership)&.id).to be > ownership2.id
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
        expect(ownership1.organization&.id).to eq bike.organizations.first.id
        expect(ownership1.first?).to be_truthy
        expect(ownership1.previous_ownership_id).to be_blank
        expect(ownership2.current?).to be_truthy
        expect(ownership2.first?).to be_falsey
        expect(ownership2.second?).to be_truthy
        expect(ownership2.organization&.id).to be_blank
        expect(ownership2.prior_ownerships.pluck(:id)).to eq([ownership1.id])
        expect(ownership2.new_registration?).to be_falsey
        expect(ownership2.previous_ownership_id).to eq ownership1.id
        expect(ownership2.claim_message).to eq "transferred_registration"
      end
    end
    context "organization" do
      let(:user) { FactoryBot.create(:user_confirmed) }
      let(:organization) { FactoryBot.create(:organization, :with_auto_user, user: user) }
      let(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization, owner_email: email, creator: user) }
      let(:ownership) { bike.ownerships.first }
      it "returns new_registration" do
        ownership.reload
        expect(ownership.organization).to eq organization
        expect(ownership.user).to be_blank
        expect(ownership.new_registration?).to be_truthy
        expect(ownership.claim_message).to eq "new_registration"
        expect(ownership.organization_pre_registration?).to be_falsey
      end
      context "organization_pre_registration?" do
        let(:email) { user.email }
        let(:ownership2) { FactoryBot.build(:ownership, bike: bike, creator: user, owner_email: "new@stuff.com") }
        let(:ownership3) { FactoryBot.create(:ownership, bike: bike, creator: user, owner_email: "new_again@stuff.com") }
        it "returns new_registration" do
          expect(bike.reload.owner_email).to eq user.email
          expect(ownership.reload.owner_email).to eq user.email
          expect(ownership.self_made?).to be_truthy
          expect(ownership.claimed?).to be_truthy
          expect(ownership.current?).to be_truthy
          expect(ownership.organization&.id).to eq organization.id
          expect(ownership.first?).to be_truthy
          expect(ownership.previous_ownership_id).to be_blank
          expect(ownership.organization_pre_registration?).to be_truthy
          expect(ownership.send_email).to be_truthy # still defaults to true
          # Before save, still works
          expect(ownership2.current).to be_truthy
          expect(ownership2.prior_ownerships.pluck(:id)).to eq([ownership.id])
          expect(ownership2.first?).to be_falsey
          expect(ownership2.second?).to be_truthy
          ownership2.save
          ownership2.reload
          ownership.reload
          expect(ownership.current?).to be_falsey
          expect(ownership.first?).to be_truthy
          expect(ownership2.current?).to be_truthy
          expect(ownership2.self_made?).to be_falsey
          expect(ownership2.first?).to be_falsey
          expect(ownership2.second?).to be_truthy
          expect(ownership2.organization_pre_registration?).to be_falsey
          expect(ownership2.previous_ownership_id).to eq ownership.id
          expect(ownership2.previous_ownership.organization_pre_registration?).to be_truthy
          expect(ownership2.prior_ownerships.pluck(:id)).to eq([ownership.id])
          expect(ownership2.previous_ownership_id).to eq ownership.id
          # Registrations that were initially from an organization member, then transferred outside of the organization,
          # count as "new" - because some organizations pre-register bikes
          expect(ownership2.new_registration?).to be_truthy
          expect(ownership2.claim_message).to eq "new_registration"

          expect(ownership3.reload.current).to be_truthy
          expect(ownership3.previous_ownership_id).to eq ownership2.id
          expect(ownership2.reload.current).to be_falsey
          expect(ownership3.organization_pre_registration?).to be_falsey
          expect(ownership3.previous_ownership.organization_pre_registration?).to be_falsey
          expect(ownership3.prior_ownerships.pluck(:id)).to match_array([ownership.id, ownership2.id])
          expect(ownership3.first?).to be_falsey
          expect(ownership3.second?).to be_falsey
          expect(ownership3.new_registration?).to be_falsey
          expect(ownership3.self_made?).to be_falsey

          expect(Ownership.self_made.pluck(:id)).to eq([ownership.id])
          expect(Ownership.not_self_made.pluck(:id)).to match_array([ownership2.id, ownership3.id])
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
    context "impound_record" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, owner_email: email) }
      let!(:ownership1) { bike.ownerships.first }
      let(:ownership2) { FactoryBot.create(:ownership, bike: bike, creator: bike.creator, owner_email: email) }
      let(:impound_record) { FactoryBot.create(:impound_record_with_organization, bike: bike) }
      let(:new_email) { "impound_user@stuff.com" }
      it "is new_registration" do
        expect(bike.reload.claimed?).to be_truthy
        expect(bike.status).to eq "status_with_owner"
        expect(ownership1.reload.user).to be_present
        expect(ownership1.new_registration?).to be_truthy
        expect(ownership1.origin).to eq "web"
        expect(ownership2.reload.claimed?).to be_falsey
        expect(ownership2.new_registration?).to be_falsey
        expect(ownership2.origin).to eq "transferred_ownership"
        expect(ownership2.claim_message).to eq "transferred_registration"

        ProcessImpoundUpdatesJob.new.perform(impound_record.id)
        expect(bike.reload.status).to eq "status_impounded"
        FactoryBot.create(:impound_record_update, impound_record: impound_record, kind: "transferred_to_new_owner", transfer_email: new_email)
        ProcessImpoundUpdatesJob.new.perform(impound_record.id)
        ownership3 = impound_record.reload.ownership
        expect(ownership3.previous_ownership_id).to eq ownership2.id
        expect(ownership3.origin).to eq "impound_process"
        expect(ownership3.owner_email).to eq new_email
        expect(ownership3.new_registration?).to be_truthy
        expect(ownership3.claim_message).to eq "new_registration"
        expect(bike.reload.status).to eq "status_with_owner"
        expect(bike.owner_email).to eq new_email
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
        expect(ownership.send(:spam_risky_email?)).to be_falsey
      end
    end
    context "example bike" do
      let(:bike) { Bike.new(example: true) }
      let(:ownership) { Ownership.new(bike: bike) }
      it "is false" do
        expect(ownership.calculated_send_email).to be_falsey
      end
    end
    context "likely_spam bike" do
      let(:bike) { Bike.new(likely_spam: true) }
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
        expect(ownership2.organization).to be_blank
        expect(ownership2.calculated_send_email).to be_truthy
      end
    end
  end

  describe "spam_risky_email?" do
    # hotmail and yahoo have been delaying our emails. In an effort to ensure delivery of really important emails (e.g. password resets)
    # skip sending ownership invitations for POS registrations, just in case
    let(:bike) { FactoryBot.create(:bike, owner_email: email) }
    let(:ownership) { Ownership.new(bike: bike, owner_email: email, pos_kind: pos_kind, origin: origin) }
    let(:origin) { "web" }
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
      context "embed registration" do
        let(:pos_kind) { "no_pos" }
        let(:origin) { "embed" }
        it "sends" do
          expect(ownership.send(:spam_risky_email?)).to be_falsey
          expect(ownership.calculated_send_email).to be_truthy
        end
        context "spam_registrations organization" do
          let(:organization) { FactoryBot.create(:organization, approved: true, spam_registrations: true) }
          it "doesn't send" do
            ownership.organization = organization
            expect(ownership.send(:spam_risky_email?)).to be_truthy
            expect(ownership.calculated_send_email).to be_falsey
          end
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
      expect(ownership.send(:calculated_organization_pre_registration?)).to be_falsey
    end
    context "organization registration" do
      let(:organization) { FactoryBot.create(:organization_with_auto_user) }
      let(:creator) { FactoryBot.create(:organization_user, organization: organization) }
      let(:owner_email) { creator.email }
      let(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization, creator: creator, owner_email: owner_email) }
      let(:ownership) { bike.ownerships.first }
      it "is falsey" do
        ownership.reload
        expect(ownership.organization_id).to eq organization.id
        expect(ownership.creator_id).to_not eq organization.auto_user_id
        expect(ownership.self_made?).to be_truthy
        expect(ownership.claimed?).to be_truthy
        expect(ownership.send(:calculated_organization_pre_registration?)).to be_falsey
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
          expect(ownership.send(:calculated_organization_pre_registration?)).to be_truthy
        end
        context "not self made" do
          let(:member) { FactoryBot.create(:organization_user, organization: organization) }
          let(:owner_email) { member.email }
          it "is falsey" do
            ownership.reload
            expect(User.fuzzy_email_find(owner_email)&.id).to_not eq creator.id
            expect(ownership.creator_id).to eq organization.auto_user_id
            expect(ownership.user_id).to_not eq creator.id
            expect(ownership.self_made?).to be_falsey
            expect(ownership.claimed?).to be_falsey
            expect(ownership.send(:calculated_organization_pre_registration?)).to be_falsey
          end
        end
        context "not first" do
          let(:ownership2) { FactoryBot.create(:ownership, bike: bike, organization: organization, creator: creator, owner_email: owner_email) }
          it "is falsey" do
            ownership.reload
            expect(ownership.send(:calculated_organization_pre_registration?)).to be_truthy
            expect(User.fuzzy_email_find(owner_email)&.id).to eq creator.id
            ownership2.reload
            expect(ownership2.prior_ownerships.pluck(:id)).to eq([ownership.id])
            expect(ownership2.previous_ownership_id).to eq ownership.id
            expect(ownership2.organization_id).to eq organization.id
            expect(ownership2.creator_id).to eq organization.auto_user_id
            expect(ownership2.user_id).to eq creator.id
            expect(ownership2.self_made?).to be_truthy
            expect(ownership2.claimed?).to be_truthy
            expect(ownership2.send(:calculated_organization_pre_registration?)).to be_truthy
            bike.reload
            expect(bike.current_ownership_id).to eq ownership2.id
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

  describe "owner_name" do
    context "registration_info" do
      let(:registration_info) { {user_name: "Cool Name"} }
      let(:bike) { FactoryBot.create(:bike, :with_ownership, creation_registration_info: registration_info) }
      let(:user) { FactoryBot.create(:user_confirmed, name: "New name", email: bike.owner_email) }
      it "is registration_info" do
        expect(bike.reload.user&.id).to be_blank
        expect(bike.current_ownership.owner_name).to eq "Cool Name"
        expect(bike.owner_name).to eq "Cool Name"
        expect(user).to be_present
        bike.current_ownership.mark_claimed
        expect(bike.reload.user&.id).to eq user.id
        expect(bike.current_ownership.owner_name).to eq "New name"
        expect(bike.owner_name).to eq "New name"
      end
      context "cleaned_registration_info" do
        let(:registration_info) { {user_name: "George", bike_code: "9998888", phone: "(111) 222-4444", student_id: "1222", organization_affiliation: "employee"} }
        let(:target_cleaned) { {user_name: "George", bike_sticker: "9998888", phone: "1112224444", student_id: "1222", organization_affiliation: "employee"}.as_json }
        let(:organized_target) { target_cleaned.merge("student_id_#{organization.id}" => "1222", "organization_affiliation_#{organization.id}" => "employee") }
        let(:organization) { FactoryBot.create(:organization) }
        let(:organization2) { FactoryBot.create(:organization) }
        it "cleans things" do
          expect(bike.reload.registration_info).to eq target_cleaned
          expect(bike.owner_name).to eq "George"

          ownership = bike.current_ownership
          expect(ownership.student_id_key).to eq "student_id"
          expect(ownership.student_id_key(organization)).to eq "student_id"
          expect(ownership.student_id_key(organization.id)).to eq "student_id"
          expect(ownership.student_id_key(organization2)).to eq "student_id"
          expect(ownership.student_id_key(organization2.slug)).to eq "student_id"
          expect(ownership.organization_affiliation).to eq "employee"
          organization_uniq_keys = OrganizationFeature.reg_fields_organization_uniq.map { |f| f.gsub("reg_", "") }
          expect(ownership.registration_info_uniq_keys).to match_array organization_uniq_keys

          expect(bike.student_id).to eq "1222"

          expect(bike.student_id(organization)).to eq "1222"
          expect(bike.student_id(organization2)).to eq "1222"
          expect(bike.organization_affiliation).to eq "employee"
          expect(bike.organization_affiliation(organization)).to eq "employee"
          expect(bike.organization_affiliation(organization2)).to eq "employee"
          expect(ownership.organization_id).to be_blank
          expect(ownership.registration_info).to eq target_cleaned
          expect(ownership.owner_name).to eq "George"
          # If there is a organization, it cleans things using the org id
          ownership.update(organization: organization)
          expect(ownership.registration_info).to eq organized_target
          expect(ownership.student_id_key).to eq "student_id"
          expect(ownership.student_id_key(organization)).to eq "student_id_#{organization.id}"
          expect(ownership.student_id_key(organization.id)).to eq "student_id_#{organization.id}"
          expect(ownership.student_id(organization.slug)).to eq "1222"
          expect(ownership.student_id(organization2)).to eq "1222"

          expect(ownership.organization_affiliation).to eq "employee"
          expect(ownership.organization_affiliation(organization)).to eq "employee"
          expect(ownership.organization_affiliation(organization.id)).to eq "employee"
          expect(ownership.organization_affiliation(organization.slug)).to eq "employee"
          expect(ownership.organization_affiliation(organization2)).to eq "employee"

          # sanity check
          expect(ownership.registration_info_uniq_keys).to match_array organization_uniq_keys

          expect(bike.reload.student_id).to eq "1222"
          expect(bike.student_id(organization)).to eq "1222"
          expect(bike.organization_affiliation).to eq "employee"
        end
      end
    end
    context "unclaimed but with user" do
      let(:user) { FactoryBot.create(:user, name: "Party Party") }
      let(:bike) { FactoryBot.create(:bike, :with_ownership, user: user) }
      it "uses the user name" do
        expect(bike.reload.owner_name).to eq "Party Party"
      end
    end
    context "with creator" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:creator) { FactoryBot.create(:user_confirmed, name: "Stephanie Example") }
      let(:new_owner) { FactoryBot.create(:user, name: "Sally Stuff", email: "sally@example.com") }
      let(:bike) { FactoryBot.create(:bike_organized, claimed: false, user: nil, creator: creator, creation_organization: organization, owner_email: "sally@example.com") }
      let(:ownership) { bike.ownerships.first }
      it "does not use creator" do
        expect(bike.reload.ownerships.count).to eq 1
        ownership.reload
        expect(ownership.claimed?).to be_falsey
        expect(ownership.organization_pre_registration?).to be_falsey
        expect(ownership.owner_name).to be_blank
        expect(bike.owner_name).to be_blank
        ownership.user = new_owner
        # Creator name is a fallback, if the bike is claimed we want to use the person who has claimed it
        ownership.mark_claimed
        bike.reload
        ownership.reload
        expect(ownership.claimed?).to be_truthy
        expect(ownership.user).to eq new_owner
        expect(bike.owner_name).to eq "Sally Stuff"
      end
    end
    context "stupid PSU bullshit" do
      # PSU makes their students create accounts and then send the bike to a different email address. So handle that
      # I'm working on convincing them to stop doing this.
      let(:organization) { FactoryBot.create(:organization, short_name: "PSU", id: 553) }
      let(:creator) { FactoryBot.create(:user_confirmed, name: "Jill Example") }
      let(:bike) { FactoryBot.create(:bike_organized, claimed: false, user: nil, creator: creator, creation_organization: organization, owner_email: "sally@example.com") }
      it "uses the creator name" do
        expect(organization.reload.id).to eq 553
        expect(bike.current_ownership.user_id).to be_blank
        expect(bike.current_ownership.owner_name).to eq "Jill Example"
      end
    end
  end
end
