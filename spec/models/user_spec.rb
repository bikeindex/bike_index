require "rails_helper"

RSpec.describe User, type: :model do
  describe ".ambassadors" do
    context "given ambassadors and no org filter" do
      it "returns any and only users who are ambassadors" do
        FactoryBot.create(:user)
        FactoryBot.create(:developer)
        ambassadors = FactoryBot.create_list(:ambassador, 3)

        found_ambassadors = User.ambassadors

        expect(found_ambassadors.pluck(:id).sort).to eq(ambassadors.map(&:id).sort)
      end
    end

    context "with no ambassadors" do
      it "returns an empty array" do
        expect(User.ambassadors).to eq([])
      end
    end

    context "with no matching users" do
      it "returns an empty array" do
        FactoryBot.create(:developer)
        expect(User.ambassadors).to eq([])
      end
    end
  end

  describe "create user_email" do
    it "creates a user_email on create" do
      user = FactoryBot.create(:user_confirmed)
      expect(user.user_emails.count).to eq 1
      expect(user.email).to eq user.user_emails.first.email
    end
  end

  describe "validate" do
    describe "create" do
      subject { User.new(FactoryBot.attributes_for(:user)) }
      before :each do
        expect(subject.valid?).to be_truthy
      end

      it "requires password on create" do
        subject.password = nil
        subject.password_confirmation = nil
        expect(subject.valid?).to be_falsey
        expect(subject.errors.messages[:password].include?("can't be blank")).to be_truthy
      end

      it "requires password and confirmation to match" do
        subject.password_confirmation = "wtf"
        expect(subject.valid?).to be_falsey
        expect(subject.errors.messages[:password_confirmation].include?("doesn't match confirmation")).to be_truthy
      end

      it "requires at least 8 characters for the password" do
        subject.password = "hi"
        subject.password_confirmation = "hi"
        expect(subject.valid?).to be_falsey
        expect(subject.errors.messages[:password].include?("is too short (minimum is 6 characters)")).to be_truthy
      end

      it "makes sure there is at least one letter" do
        subject.password = "1234567890"
        subject.password_confirmation = "1234567890"
        expect(subject.valid?).to be_falsey
        expect(subject.errors.messages[:password].include?("must contain at least one letter")).to be_truthy
      end

      it "doesn't let unconfirmed users have the same password" do
        FactoryBot.create(:user, email: subject.email)
        expect(subject.valid?).to be_falsey
        expect(subject.errors.messages[:email]).to be_present
      end

      it "doesn't let confirmed users have the same password" do
        FactoryBot.create(:user_confirmed, email: subject.email)
        expect(subject.valid?).to be_falsey
        expect(subject.errors.messages[:email]).to be_present
      end

      it "validates preferred_language" do
        subject.preferred_language = nil
        expect(subject.valid?).to eq(true)
        subject.preferred_language = "en"
        expect(subject.valid?).to eq(true)
        subject.preferred_language = "klingon"
        expect(subject.valid?).to eq(false)
      end
    end

    describe "confirm" do
      let(:user) { FactoryBot.create(:user) }

      it "requires confirmation" do
        expect(user.confirmed).to be_falsey
        expect(user.confirmation_token).not_to be_nil
      end

      it "confirms users" do
        expect(user.confirmed).to be_falsey
        expect(user.confirm(user.confirmation_token)).to be_truthy
        expect(user.confirmed).to be_truthy
        expect(user.confirmation_token).to be_nil
      end

      it "fails to confirm users" do
        expect(user.confirm("wtfmate")).to be_falsey
        expect(user.confirmed).to be_falsey
        expect(user.confirmation_token).not_to be_nil
      end

      it "is bannable" do
        user.banned = true
        user.save
        expect(user.authenticate("testme21")).to eq(false)
      end
    end

    describe "update" do
      before :each do
        @user = FactoryBot.create(:user)
        expect(@user.valid?).to be_truthy
      end

      it "requires password and confirmation to match" do
        @user.password_confirmation = "wtf"
        expect(@user.valid?).to be_falsey
        expect(@user.errors.messages[:password_confirmation].include?("doesn't match confirmation")).to be_truthy
      end

      it "requires at least 8 characters for the password" do
        @user.password = "hi"
        @user.password_confirmation = "hi"
        expect(@user.valid?).to be_falsey
        expect(@user.errors.messages[:password].include?("is too short (minimum is 6 characters)")).to be_truthy
      end

      it "makes sure there is at least one letter" do
        @user.password = "1234567890"
        @user.password_confirmation = "1234567890"
        expect(@user.valid?).to be_falsey
        expect(@user.errors.messages[:password].include?("must contain at least one letter")).to be_truthy
      end
    end
  end

  describe "authorized?" do
    let(:user) { FactoryBot.create(:user) }
    let(:organization) { FactoryBot.create(:organization) }
    let(:organization_member) { FactoryBot.create(:organization_member, organization: organization) }
    let(:ownership) { FactoryBot.create(:ownership_organization_bike, organization: organization) }
    let(:bike) { ownership.bike }
    let(:admin) { User.new(superuser: true) }
    it "returns expected values" do
      expect(user.authorized?(bike)).to be_falsey
      expect(user.authorized?(organization)).to be_falsey
      expect(admin.authorized?(bike)).to be_truthy
      expect(admin.authorized?(organization)).to be_truthy
      expect(ownership.creator.authorized?(bike)).to be_truthy
      expect(organization_member.authorized?(bike)).to be_truthy
      expect(organization_member.authorized?(organization)).to be_truthy
    end
    context "bike_sticker" do
      let(:organization2) { FactoryBot.create(:organization) }
      let(:organization2_member) { FactoryBot.create(:organization_member, organization: organization2) }
      let(:owner) { ownership.creator }
      let!(:bike_organization) { FactoryBot.create(:bike_organization, bike: bike, organization: organization2, can_edit_claimed: true) }
      let(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, bike: bike) }
      it "is truthy for admins and org members and code claimer" do
        # Sanity check bike authorization
        expect(bike.authorized?(user)).to be_falsey
        expect(bike.authorized?(owner)).to be_truthy
        expect(bike.authorized?(organization_member)).to be_truthy
        expect(bike.authorized?(admin)).to be_truthy
        # Check user authorization
        expect(user.authorized?(bike)).to be_falsey
        expect(owner.authorized?(bike)).to be_truthy
        expect(organization_member.authorized?(bike)).to be_truthy
        expect(admin.authorized?(bike)).to be_truthy
        # Check bike code authorization
        expect(bike_sticker.authorized?(user)).to be_falsey
        expect(bike_sticker.authorized?(owner)).to be_truthy
        expect(bike_sticker.authorized?(organization_member)).to be_truthy
        expect(bike_sticker.authorized?(admin)).to be_truthy
      end
    end
  end

  describe "fuzzy finds" do
    before do
      expect(user).to be_present
    end
    context "confirmed user" do
      let(:user) { FactoryBot.create(:user_confirmed, email: "ned@foo.com") }
      context "primary email" do
        it "finds users by email address when the case doesn't match" do
          expect(User.fuzzy_email_find("NeD@fOO.cOM ")).to eq(user)
          expect(User.fuzzy_confirmed_or_unconfirmed_email_find("NeD@fOO.cOM ")).to eq user
        end
      end
      context "secondary email" do
        let(:email) { "another@foo.com" }
        let(:secondary_email) { FactoryBot.create(:user_email, user: user, email: email) }
        it "finds users by secondary email" do
          expect(secondary_email.confirmed).to be_truthy
          expect(secondary_email.user).to eq user
          expect(user.secondary_emails.include?(email)).to be_truthy
          expect(User.fuzzy_email_find(email)).to eq user
          expect(User.fuzzy_confirmed_or_unconfirmed_email_find(email)).to eq user
        end
      end
    end
    describe "fuzzy_unconfirmed_primary_email_find" do
      let(:user) { FactoryBot.create(:user, email: "ned@foo.com") }
      it "finds user" do
        expect(user.confirmed).to be_falsey
        expect(User.fuzzy_unconfirmed_primary_email_find(" NeD@fOO.com ")).to eq user
        expect(User.fuzzy_confirmed_or_unconfirmed_email_find(" NeD@fOO.com ")).to eq user
      end
    end
  end

  describe "admin text search" do
    context "secondary email partial match" do
      let(:user_email) do
        FactoryBot.create(:user_email,
                          email: "urrg@second.org",
                          user: FactoryBot.create(:user, name: "FeconDDD"))
      end
      let!(:user) { user_email.user }
      it "finds users, deduping" do
        expect(User.admin_text_search("econd").pluck(:id)).to eq([user.id])
      end
    end
    context "unconfirmed user partial match" do
      let!(:user) { FactoryBot.create(:user, email: "sample-stuff@e.us") }
      it "finds users" do
        expect(user.confirmed).to be_falsey
        expect(User.admin_text_search("sample-stuff@e.us").pluck(:id)).to eq([user.id])
      end
    end
    context "partial match for name" do
      let!(:user) { FactoryBot.create(:user, name: "XYLoPHONE") }
      it "finds user" do
        expect(User.admin_text_search("ylop").pluck(:id)).to eq([user.id])
      end
    end
  end

  describe "secondary_emails" do
    let(:user) { FactoryBot.create(:user_confirmed, email: "cool@stuff.com") }
    let(:user_email) { FactoryBot.create(:user_email, user: user) }
    it "lists the non-primary emails" do
      expect(user_email).to be_present
      expect(user.secondary_emails).to eq([user_email.email])
    end
  end

  describe "stolen records missing locations" do
    let(:user) { FactoryBot.create(:user) }
    let(:ownership) { FactoryBot.create(:ownership_claimed, creator: user, user: user) }
    let!(:stolen_record) { FactoryBot.create(:stolen_record, bike: ownership.bike, street: "         ") }
    let(:ownership_with_location) { FactoryBot.create(:ownership_claimed, creator: user, user: user) }
    let!(:stolen_record_with_location) { FactoryBot.create(:stolen_record, bike: ownership_with_location.bike, street: "some cool street") }
    let(:ownership_unclaimed) { FactoryBot.create(:ownership, creator: user) }
    let!(:stolen_record_unclaimed) { FactoryBot.create(:stolen_record, bike: ownership_unclaimed.bike) }
    it "lists the bikes with missing locations" do
      # Ensure we've got the current stolen records set
      stolen_record.bike.update_attributes(updated_at: Time.current)
      stolen_record_with_location.bike.update_attributes(updated_at: Time.current)
      stolen_record_unclaimed.bike.update_attributes(updated_at: Time.current)
      expect(stolen_record.bike.current_stolen_record).to eq stolen_record
      expect(stolen_record_with_location.bike.current_stolen_record).to eq stolen_record_with_location
      expect(stolen_record_unclaimed.bike.current_stolen_record).to eq stolen_record_unclaimed
      # Test that the missing location is there
      expect(stolen_record.missing_location?).to be_truthy
      expect(stolen_record_with_location.missing_location?).to be_falsey
      expect(stolen_record_unclaimed.missing_location?).to be_truthy
      expect(stolen_record.bike.user).to eq user
      expect(stolen_record_with_location.bike.user).to eq user
      expect(stolen_record_unclaimed.bike.user).to be_blank
      # Unmemoize the stolen_bikes_without_locations
      user_id = user.id
      user = User.find(user_id)
      user.save
      expect(user.stolen_bikes_without_locations.map(&:id)).to eq([stolen_record.bike_id])
      expect(user.has_stolen_bikes_without_locations).to be_truthy
      user.update_attributes(superuser: true)
      expect(user.has_stolen_bikes_without_locations).to be_falsey
    end
  end

  describe "set_calculated_attributes" do
    describe "title, urls" do
      it "adds http:// to twitter and website if the url doesn't have it so that the link goes somewhere" do
        user = User.new(show_twitter: true, twitter: "http://somewhere.com", show_website: true, website: "somewhere.org")
        user.set_calculated_attributes
        expect(user.website).to eq("http://somewhere.org")
      end
      it "does not add http:// to twitter if it's already there" do
        user = User.new(show_twitter: true, twitter: "http://somewhere.com", show_website: true, website: "somewhere", my_bikes_link_target: "https://something.com")
        user.set_calculated_attributes
        expect(user.my_bikes_hash["link_target"]).to eq("https://something.com")
        expect(user.mb_link_target).to eq("https://something.com")
        expect(user.twitter).to eq("http://somewhere.com")
      end
    end
    it "doesn't let you overwrite usernames" do
      target = "coolname"
      user1 = FactoryBot.create(:user)
      user1.update_attribute :username, target
      expect(user1.reload.username).to eq(target)
      user2 = FactoryBot.create(:user)
      user2.username = "#{target}'"
      expect(user2.save).to be_falsey
      expect(user2.errors.full_messages.to_s).to match("Username has already been taken")
      expect(user2.reload.username).not_to eq(target)
      expect(user1.reload.username).to eq(target)
    end
  end

  describe "email and phone" do
    let(:user) { FactoryBot.build(:user, phone: "773.83ddp+83(887)", email: "SOMethinG@example.com\n") }
    before(:each) { user.set_calculated_attributes }

    it "strips the non-digit numbers from the phone input" do
      expect(user.phone).to eq("7738383887")
    end

    it "normalizes the email" do
      expect(user.email).to eq("something@example.com")
    end
  end

  describe "bikes" do
    it "returns nil if the user has no bikes" do
      user = FactoryBot.create(:user)
      expect(user.bikes).to be_empty
    end
    it "returns the user's bikes if they have any hidden bikes without the hidden bikes" do
      user = FactoryBot.create(:user)
      o = FactoryBot.create(:ownership, owner_email: user.email, user_id: user.id)
      o2 = FactoryBot.create(:ownership, owner_email: user.email, user_id: user.id)
      o2.bike.update_attribute :hidden, true
      expect(user.bike_ids.include?(o.bike.id)).to be_truthy
      expect(user.bike_ids.include?(o2.bike.id)).not_to be_truthy
      expect(user.bike_ids.count).to eq(1)
    end
    it "returns the user's bikes if they have any hidden bikes without the hidden bikes" do
      user = FactoryBot.create(:user)
      ownership = FactoryBot.create(:ownership, owner_email: user.email, user_id: user.id, user_hidden: true)
      ownership.bike.update_attribute :hidden, true
      expect(user.bike_ids.include?(ownership.bike.id)).to be_truthy
    end
    it "returns the user's bikes without hidden bikes if user_hidden" do
      user = FactoryBot.create(:user)
      ownership = FactoryBot.create(:ownership, owner_email: user.email, user_id: user.id, user_hidden: true)
      ownership.bike.update_attribute :hidden, true
      expect(user.bike_ids(false).include?(ownership.bike.id)).to be_falsey
    end
  end

  describe "generate_username_confirmation_and_auth" do
    it "generates the required tokens" do
      user = FactoryBot.create(:user)
      expect(user.auth_token).to be_present
      expect(user.username).to be_present
      expect(user.confirmation_token).to be_present
      time = Time.at(SecurityTokenizer.token_time(user.auth_token))
      expect(time).to be > Time.current - 1.minutes
    end
    it "haves before create callback" do
      expect(User._create_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:generate_username_confirmation_and_auth)).to eq(true)
    end
  end

  describe "access_tokens_for_application" do
    it "returns [] if no application" do
      user = User.new
      expect(user.access_tokens_for_application(nil)).to eq([])
    end
    it "returns access tokens for the application" do
      user = FactoryBot.create(:user)
      application = Doorkeeper::Application.new(name: "test", redirect_uri: "https://foo.bar")
      application2 = Doorkeeper::Application.new(name: "other_test", redirect_uri: "https://foo.bar")
      application.owner = user
      application.save
      application2.owner = user
      application2.save
      access_token = Doorkeeper::AccessToken.create(application_id: application.id, resource_owner_id: user.id)
      access_token2 = Doorkeeper::AccessToken.create(application_id: application2.id, resource_owner_id: user.id)
      tokens = user.reload.access_tokens_for_application(application.id)
      expect(tokens.first).to eq(access_token)
      tokens = user.reload.access_tokens_for_application(application2.id)
      expect(tokens.first).to eq(access_token2)
    end
  end

  describe "auth_token_time" do
    context "password_reset_token" do
      it "gets long time ago if not there" do
        user = User.new(password_reset_token: "c7c3b99a319ac09e2b0080a8s89asd89afsd6734n")
        expect(user.auth_token_time("password_reset_token")).to eq(Time.at(SecurityTokenizer::EARLIEST_TOKEN_TIME))
      end
      it "gets the time" do
        user = FactoryBot.create(:user)
        expect(user.password_reset_token).to be_blank
        user.update_auth_token("password_reset_token")
        user.reload
        expect(user.password_reset_token).to be_present
        expect(user.auth_token_time("password_reset_token")).to be > Time.current - 2.seconds
      end
      it "uses input time" do
        user = FactoryBot.create(:user)
        user.update_auth_token("password_reset_token", (Time.current - 61.minutes).to_i)
        expect(user.reload.auth_token_time("password_reset_token")).to be < (Time.current - 1.hours)
      end
    end

    context "magic_link_token" do
      it "gets long time ago if not there" do
        user = User.new(magic_link_token: "c7c3b99a319ac09e2b00-89121981231231331212")
        expect(user.auth_token_time("magic_link_token")).to eq(Time.at(SecurityTokenizer::EARLIEST_TOKEN_TIME))
      end
      it "gets the time" do
        user = User.new
        user.generate_auth_token("magic_link_token")
        expect(user.auth_token_time("magic_link_token")).to be > Time.current - 2.seconds
      end
      it "uses input time, it returns the token" do
        user = FactoryBot.create(:user)
        user.update_auth_token("magic_link_token", (Time.current - 61.minutes).to_i)
        user.reload
        expect(user.auth_token_time("magic_link_token")).to be < (Time.current - 1.hours)
      end
    end
  end

  describe "send_password_reset_email" do
    it "enqueues sending the password reset" do
      user = FactoryBot.create(:user)
      expect(user.password_reset_token).to be_nil
      expect do
        user.send_password_reset_email
      end.to change(EmailResetPasswordWorker.jobs, :size).by(1)
      expect(user.reload.password_reset_token).not_to be_nil
    end

    it "doesn't send another one immediately" do
      user = FactoryBot.create(:user)
      user.send_password_reset_email
      current_token = user.password_reset_token
      expect do
        user.send_password_reset_email
        user.send_password_reset_email
      end.to change(EmailResetPasswordWorker.jobs, :size).by(0)
      user.reload
      expect(user.password_reset_token).to eq current_token
    end
  end

  describe "send_magic_link_email" do
    it "enqueues sending the password reset" do
      user = FactoryBot.create(:user)
      expect(user.magic_link_token).to be_nil
      expect do
        user.send_magic_link_email
      end.to change(EmailMagicLoginLinkWorker.jobs, :size).by(1)
      expect(user.reload.magic_link_token).not_to be_nil
    end

    it "doesn't send another one immediately (or alter the token)" do
      user = FactoryBot.create(:user)
      user.send_magic_link_email
      token = user.magic_link_token
      user.send_magic_link_email
      expect do
        user.send_magic_link_email
      end.to change(EmailResetPasswordWorker.jobs, :size).by(0)
      user.reload
      expect(user.magic_link_token).to eq token
    end
  end

  describe "update_last_login" do
    let(:user) { FactoryBot.create(:user) }
    let(:update_time) { Time.current - 3.hours }
    it "updates the last sign in for the user, regardless of whether there are errors" do
      user.update_column :updated_at, update_time
      user.reload
      expect(user.updated_at).to be_within(1.second).of update_time
      expect(user.last_login_at).to be_blank
      expect(user.last_login_ip).to be_blank
      user.password = nil
      user.save
      expect(user.errors).to be_present
      user.update_last_login("127.0.0.1")
      expect(user.errors).to be_present
      user.reload
      expect(user.last_login_at).to be_present
      expect(user.last_login_ip).to be_present
      expect(user.updated_at).to be_within(1.second).of update_time
    end
    context "user is not saved" do
      let(:user) { FactoryBot.build(:user) }
      it "raises an informative error" do
        user.password = nil
        expect do
          user.update_last_login("127.0.0.1")
        end.to raise_error(/password/i)
      end
    end
  end

  describe "friendly_id_find" do
    it "fails with nil" do
      result = User.friendly_id_find("some stuff")
      expect(result).to be_nil
    end
  end

  describe "send_unstolen_notifications?" do
    let(:user) { User.new }
    it "is falsey, truthy for superuser" do
      expect(user.send_unstolen_notifications?).to be_falsey
      user.superuser = true
      expect(user.send_unstolen_notifications?).to be_truthy
    end

    it "returns true for an ambassador" do
      ambassador = FactoryBot.create(:ambassador)
      expect(ambassador.send_unstolen_notifications?).to eq(true)
    end

    context "organization" do
      let(:user) { FactoryBot.create(:organization_member) }
      let(:organization) { user.organizations.first }
      let!(:invoice) { FactoryBot.create(:invoice_paid, amount_due: 0, organization: organization) }
      let!(:paid_feature) { FactoryBot.create(:paid_feature, name: "unstolen notifications", feature_slugs: ["unstolen_notifications"]) }
      it "is true if the organization has that paid feature" do
        expect(user.render_donation_request).to be_nil
        expect(user.send_unstolen_notifications?).to be_falsey

        invoice.update_attributes(paid_feature_ids: [paid_feature.id])
        organization.save

        expect(organization.bike_actions?).to be_truthy
        expect(Organization.bike_actions.pluck(:id)).to eq([organization.id])
        expect(user.reload.send_unstolen_notifications?).to be_truthy
      end
    end
  end

  describe "render_donation_request" do
    let(:organization) { FactoryBot.create(:organization, kind: "bike_advocacy") }
    let(:user) { FactoryBot.create(:organization_member, organization: organization) }
    it "is nil" do
      expect(User.new.render_donation_request).to be_nil
    end
    context "user part of a advocacy group" do
      it "is nil" do
        user.reload
        expect(user.render_donation_request).to be_nil
      end
    end
    context "user is part of a police department" do
      let(:organization) { FactoryBot.create(:organization, kind: "law_enforcement") }
      it "is nil" do
        user.reload
        expect(user.render_donation_request).to eq "law_enforcement"
      end
      context "police department paid" do
        before { organization.update_column :is_paid, true }
        it "is 'law_enforcement'" do
          user.reload
          expect(user.organizations.paid.count).to eq 1
          expect(user.render_donation_request).to be_nil
        end
      end
    end
  end

  describe "donations" do
    let(:user) { FactoryBot.create(:user) }
    it "returns the payment amount" do
      Payment.create(user: user, amount_cents: 200)
      expect(user.donations).to eq 200
      expect(user.donor?).to be_falsey
      Payment.create(user: user, amount_cents: 800)
      expect(user.donor?).to be_truthy
    end
  end

  describe "subscriptions" do
    it "returns the payment if payment is subscription" do
      user = FactoryBot.create(:user)
      Payment.create(is_recurring: true, user_id: user)
      expect(user.subscriptions).to eq(user.payments.where(is_recurring: true))
    end
  end

  describe "userlink" do
    it "returns user path if user show" do
      user = User.new(show_bikes: true, username: "coolstuff")
      expect(user.userlink).to eq("/users/coolstuff")
    end

    it "returns twitter if user twitter" do
      user = User.new(show_bikes: false, username: "coolstuff", twitter: "bikeindex")
      expect(user.userlink).to eq("https://twitter.com/bikeindex")
    end
  end

  describe "primary_user_email" do
    it "can not set a unconfirmed email to the primary email"
  end

  describe "additional_emails=" do
    let(:user) { FactoryBot.create(:user_confirmed) }
    before do
      expect(user.user_emails.count).to eq 1
    end
    context "blank" do
      it "does nothing" do
        expect do
          user.additional_emails = " "
          user.save
        end.to change(UserEmail, :count).by 0
        expect(UserEmail.where(user_id: user.id).count).to eq 1
      end
    end
    context "a single email" do
      it "adds the email" do
        expect do
          user.additional_emails = "stuffthings@oooooooooh.com"
          user.save
        end.to change(UserEmail, :count).by 1
        user.reload
        expect(user.user_emails.confirmed.count).to eq 1
        expect(user.user_emails.unconfirmed.count).to eq 1
        expect(user.user_emails.unconfirmed.first.email).to eq "stuffthings@oooooooooh.com"
      end
    end
    context "list with repeats" do
      it "adds the non-duped emails" do
        user.additional_emails = "stuffthings@oooooooooh.com,another_email@cool.com"
        user.save
        user.reload
        expect(UserEmail.unconfirmed.where(user_id: user.id).count).to eq 2
        second_confirmed = UserEmail.where(user_id: user.id, email: "stuffthings@oooooooooh.com").first
        second_confirmed.confirm(second_confirmed.confirmation_token)
        user.reload
        expect(user.user_emails.confirmed.count).to eq 2
        expect(user.user_emails.unconfirmed.count).to eq 1
        expect do
          user.additional_emails = " andAnother@cool.com,stuffthings@oooooooooh.com,another_email@cool.com,lols@stuff.com"
          user.save
        end.to change(UserEmail, :count).by 2
        user.reload
        expect(user.user_emails.confirmed.count).to eq 2
        expect(user.user_emails.where(email: "andanother@cool.com").count).to eq 1
      end
    end
  end

  describe "member_of?" do
    let(:organization) { FactoryBot.create(:organization) }
    context "admin of organization" do
      let(:user) { FactoryBot.create(:organization_admin, organization: organization) }
      it "returns true" do
        expect(user.member_of?(organization)).to be_truthy
      end
    end
    context "member of organization" do
      let(:user) { FactoryBot.create(:organization_member, organization: organization) }
      let(:organization_child) { FactoryBot.create(:organization, parent_organization: organization) }
      let!(:user_child) { FactoryBot.create(:organization_member, organization: organization_child) }
      it "returns true" do
        organization.save
        expect(organization.child_organizations).to eq([organization_child])
        expect(user.member_of?(organization)).to be_truthy
        expect(user.member_of?(organization_child)).to be_falsey
        expect(user.authorized?(organization)).to be_truthy
        expect(user.authorized?(organization_child)).to be_falsey
        # And also check child
        expect(user_child.member_of?(organization)).to be_falsey
        expect(user_child.member_of?(organization_child)).to be_truthy
        expect(user_child.authorized?(organization)).to be_falsey
        expect(user_child.authorized?(organization_child)).to be_truthy
      end
    end
    context "superadmin" do
      let(:user) { FactoryBot.create(:admin) }
      it "returns true" do
        expect(user.member_of?(organization)).to be_truthy
      end
    end
    context "incorrect searching" do
      let(:user) { FactoryBot.create(:organization_admin, organization: organization) }
      context "non-member" do
        let(:other_organization) { FactoryBot.create(:organization) }
        it "returns false" do
          expect(other_organization).to be_present
          expect(user.member_of?(other_organization)).to be_falsey
        end
      end
      context "no organization" do
        it "returns false" do
          expect(user.member_of?(nil)).to be_falsey
        end
      end
    end
  end

  describe "ambassador?" do
    it "returns true if the user has any ambassadorship" do
      user = FactoryBot.create(:ambassador)
      user.memberships << FactoryBot.create(:membership_claimed, user: user)
      user.save

      expect(user).to be_ambassador
    end

    it "returns false if the user has no ambassadorships" do
      user = FactoryBot.create(:organization_member)
      expect(user).to_not be_ambassador
    end
  end

  describe "admin_of?" do
    let(:organization) { FactoryBot.create(:organization) }
    context "admin of organization" do
      let(:user) { FactoryBot.create(:organization_admin, organization: organization) }
      it "returns true" do
        expect(user.admin_of?(organization)).to be_truthy
      end
    end
    context "member of organization" do
      let(:user) { FactoryBot.create(:organization_member, organization: organization) }
      it "returns true" do
        expect(user.admin_of?(organization)).to be_falsey
      end
    end
    context "superadmin" do
      let(:user) { FactoryBot.create(:admin) }
      it "returns true" do
        expect(user.admin_of?(organization)).to be_truthy
      end
    end
    context "incorrect searching" do
      let(:user) { FactoryBot.create(:organization_admin, organization: organization) }
      context "non-member" do
        let(:other_organization) { FactoryBot.create(:organization) }
        it "returns false" do
          expect(other_organization).to be_present
          expect(user.admin_of?(other_organization)).to be_falsey
        end
      end
      context "no organization" do
        it "returns false" do
          expect(user.admin_of?(nil)).to be_falsey
        end
      end
    end
  end
end
