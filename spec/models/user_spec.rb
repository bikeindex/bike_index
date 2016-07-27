require 'spec_helper'

describe User do
  describe 'validations' do
    it { is_expected.to have_many :user_emails }
    it { is_expected.to have_many :payments }
    it { is_expected.to have_many :subscriptions }
    it { is_expected.to have_many :memberships }
    it { is_expected.to have_many :organization_embeds }
    it { is_expected.to have_many :organizations }
    it { is_expected.to have_many :ownerships }
    it { is_expected.to have_many :current_ownerships }
    it { is_expected.to have_many :owned_bikes }
    it { is_expected.to have_many :currently_owned_bikes }
    it { is_expected.to have_many :integrations }
    it { is_expected.to have_many :created_ownerships }
    it { is_expected.to have_many :locks }
    it { is_expected.to have_many :organization_invitations }
    it { is_expected.to have_many :oauth_applications }
    it { is_expected.to have_many :sent_stolen_notifications }
    it { is_expected.to have_many :received_stolen_notifications }
    it { is_expected.to serialize :paid_membership_info }
    it { is_expected.to serialize :my_bikes_hash }
    it { is_expected.to validate_presence_of :email }
    # it { is_expected.to validate_uniqueness_of :email }
  end

  describe 'create user_email' do
    it 'creates a user_email on create' do
      user = FactoryGirl.create(:confirmed_user)
      expect(user.user_emails.count).to eq 1
      expect(user.email).to eq user.user_emails.first.email
    end
  end

  describe 'validate' do
    describe 'create' do
      before :each do
        @user = User.new(FactoryGirl.attributes_for(:user))
        expect(@user.valid?).to be_truthy
      end

      it 'requires password on create' do
        @user.password = nil
        @user.password_confirmation = nil
        expect(@user.valid?).to be_falsey
        expect(@user.errors.messages[:password].include?("can't be blank")).to be_truthy
      end

      it 'requires password and confirmation to match' do
        @user.password_confirmation = 'wtf'
        expect(@user.valid?).to be_falsey
        expect(@user.errors.messages[:password_confirmation].include?("doesn't match confirmation")).to be_truthy
      end

      it 'requires at least 8 characters for the password' do
        @user.password = 'hi'
        @user.password_confirmation = 'hi'
        expect(@user.valid?).to be_falsey
        expect(@user.errors.messages[:password].include?('is too short (minimum is 6 characters)')).to be_truthy
      end

      it 'makes sure there is at least one letter' do
        @user.password = '1234567890'
        @user.password_confirmation = '1234567890'
        expect(@user.valid?).to be_falsey
        expect(@user.errors.messages[:password].include?('must contain at least one letter')).to be_truthy
      end

      it "doesn't let unconfirmed users have the same password" do
        FactoryGirl.create(:user, email: @user.email)
        expect(@user.valid?).to be_falsey
        expect(@user.errors.messages[:email]).to be_present
      end

      it "doesn't let confirmed users have the same password" do
        FactoryGirl.create(:confirmed_user, email: @user.email)
        expect(@user.valid?).to be_falsey
        expect(@user.errors.messages[:email]).to be_present
      end
    end

    describe 'confirm' do
      let(:user) { FactoryGirl.create(:user) }

      it 'requires confirmation' do
        expect(user.confirmed).to be_falsey
        expect(user.confirmation_token).not_to be_nil
      end

      it 'confirms users' do
        expect(user.confirmed).to be_falsey
        expect(user.confirm(user.confirmation_token)).to be_truthy
        expect(user.confirmed).to be_truthy
        expect(user.confirmation_token).to be_nil
      end

      it 'fails to confirm users' do
        expect(user.confirm('wtfmate')).to be_falsey
        expect(user.confirmed).to be_falsey
        expect(user.confirmation_token).not_to be_nil
      end

      it 'is bannable' do
        user.banned = true
        user.save
        expect(user.authenticate('testme21')).to eq(false)
      end
    end

    describe 'update' do
      before :each do
        @user = FactoryGirl.create(:user)
        expect(@user.valid?).to be_truthy
      end

      # Disabled in upgrade to rails 4 - I don't think this tests what it should be testing
      # it 'does not require a password on update' do
      #   @user.save
      #   @user.password = nil
      #   @user.password_confirmation = nil
      #   expect(@user.valid?).to be_truthy
      # end

      it 'requires password and confirmation to match' do
        @user.password_confirmation = 'wtf'
        expect(@user.valid?).to be_falsey
        expect(@user.errors.messages[:password_confirmation].include?("doesn't match confirmation")).to be_truthy
      end

      it 'requires at least 8 characters for the password' do
        @user.password = 'hi'
        @user.password_confirmation = 'hi'
        expect(@user.valid?).to be_falsey
        expect(@user.errors.messages[:password].include?('is too short (minimum is 6 characters)')).to be_truthy
      end

      it 'makes sure there is at least one letter' do
        @user.password = '1234567890'
        @user.password_confirmation = '1234567890'
        expect(@user.valid?).to be_falsey
        expect(@user.errors.messages[:password].include?('must contain at least one letter')).to be_truthy
      end
    end
  end

  describe 'admin_authorized' do
    before :all do
      @content = FactoryGirl.create(:user, is_content_admin: true)
      @admin = FactoryGirl.create(:admin)
    end

    it 'auths full' do
      expect(@admin.admin_authorized('full')).to be_truthy
      expect(@content.admin_authorized('full')).to be_falsey
    end

    it 'auths content' do
      expect(@admin.admin_authorized('content')).to be_truthy
      expect(@content.admin_authorized('content')).to be_truthy
    end

    it 'auths any' do
      expect(@admin.admin_authorized('any')).to be_truthy
      expect(@content.admin_authorized('any')).to be_truthy
    end
  end

  describe 'fuzzy_email_find' do
    it "finds users by email address when the case doesn't match" do
      @user = FactoryGirl.create(:confirmed_user, email: 'ned@foo.com')
      expect(User.fuzzy_email_find('NeD@fOO.coM')).to eq(@user)
    end
  end

  describe 'set_urls' do
    xit "adds http:// to twitter and website if the url doesn't have it so that the link goes somewhere" do
      user = User.new(show_twitter: true, twitter: 'http://somewhere.com', show_website: true, website: 'somewhere.org')
      user.set_urls
      expect(user.website).to eq('http://somewhere.org')
    end
    it "does not add http:// to twitter if it's already there" do
      user = User.new(show_twitter: true, twitter: 'http://somewhere.com', show_website: true, website: 'somewhere', my_bikes_link_target: 'https://something.com')
      user.set_urls
      expect(user.my_bikes_hash[:link_target]).to eq('https://something.com')
      expect(user.twitter).to eq('http://somewhere.com')
    end
  end

  describe 'bikes' do
    it 'returns nil if the user has no bikes' do
      user = FactoryGirl.create(:user)
      expect(user.bikes).to be_empty
    end
    it "returns the user's bikes if they have any hidden bikes without the hidden bikes" do
      user = FactoryGirl.create(:user)
      o = FactoryGirl.create(:ownership, owner_email: user.email, user_id: user.id)
      o2 = FactoryGirl.create(:ownership, owner_email: user.email, user_id: user.id)
      o2.bike.update_attribute :hidden, true
      expect(user.bike_ids.include?(o.bike.id)).to be_truthy
      expect(user.bike_ids.include?(o2.bike.id)).not_to be_truthy
      expect(user.bike_ids.count).to eq(1)
    end
    it "returns the user's bikes if they have any hidden bikes without the hidden bikes" do
      user = FactoryGirl.create(:user)
      ownership = FactoryGirl.create(:ownership, owner_email: user.email, user_id: user.id, user_hidden: true)
      ownership.bike.update_attribute :hidden, true
      expect(user.bike_ids.include?(ownership.bike.id)).to be_truthy
    end
    it "returns the user's bikes without hidden bikes if user_hidden" do
      user = FactoryGirl.create(:user)
      ownership = FactoryGirl.create(:ownership, owner_email: user.email, user_id: user.id, user_hidden: true)
      ownership.bike.update_attribute :hidden, true
      expect(user.bike_ids(false).include?(ownership.bike.id)).to be_falsey
    end
  end

  describe 'generate_username_confirmation_and_auth' do
    it 'generates the required tokens' do
      user = FactoryGirl.create(:user)
      expect(user.auth_token).to be_present
      expect(user.username).to be_present
      expect(user.confirmation_token).to be_present
      time = Time.at(user.auth_token.match(/\d*\z/)[0].to_i)
      expect(time).to be > Time.now - 1.minutes
    end
    it 'haves before create callback' do
      expect(User._create_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:generate_username_confirmation_and_auth)).to eq(true)
    end
  end

  describe 'access_tokens_for_application' do
    it 'returns [] if no application' do
      user = User.new
      expect(user.access_tokens_for_application(nil)).to eq([])
    end
    it 'returns access tokens for the application' do
      user = FactoryGirl.create(:user)
      application = Doorkeeper::Application.new(name: 'test', redirect_uri: 'https://foo.bar')
      application2 = Doorkeeper::Application.new(name: 'other_test', redirect_uri: 'https://foo.bar')
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

  describe 'reset_token_time' do
    it 'gets long time ago if not there' do
      user = User.new
      allow(user).to receive(:password_reset_token).and_return('c7c3b99a319ac09e2b00-2015-03-31 19:29:52 -0500')
      expect(user.reset_token_time).to eq(Time.at(1364777722))
    end
    it 'gets the time' do
      user = User.new
      user.set_password_reset_token
      expect(user.reset_token_time).to be > Time.now - 2.seconds
    end
    it 'uses input time' do
      user = FactoryGirl.create(:user)
      user.set_password_reset_token((Time.now - 61.minutes).to_i)
      expect(user.reload.reset_token_time).to be < (Time.now - 1.hours)
    end
  end

  describe 'send_password_reset_email' do
    it 'enqueues sending the password reset' do
      user = FactoryGirl.create(:user)
      expect(user.password_reset_token).to be_nil
      expect do
        user.send_password_reset_email
      end.to change(EmailResetPasswordWorker.jobs, :size).by(1)
      expect(user.reload.password_reset_token).not_to be_nil
    end

    it "doesn't send another one immediately" do
      user = FactoryGirl.create(:user)
      user.send_password_reset_email
      expect(user).not_to receive(:set_password_reset_token)
      user.send_password_reset_email
      expect do
        user.send_password_reset_email
      end.to change(EmailResetPasswordWorker.jobs, :size).by(0)
    end
  end

  describe 'friendly_id_find' do
    it 'fails with nil' do
      result = User.friendly_id_find('some stuff')
      expect(result).to be_nil
    end
  end

  describe 'normalize_attributes' do
    it "doesn't let you overwrite usernames" do
      target = 'coolname'
      user1 = FactoryGirl.create(:user)
      user1.update_attribute :username, target
      expect(user1.reload.username).to eq(target)
      user2 = FactoryGirl.create(:user)
      user2.username = "#{target}'"
      expect(user2.save).to be_falsey
      expect(user2.errors.full_messages.to_s).to match('Username has already been taken')
      expect(user2.reload.username).not_to eq(target)
      expect(user1.reload.username).to eq(target)
    end

    it 'has before validation callback for normalizing' do
      expect(User._validation_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:normalize_attributes)).to eq(true)
    end
  end

  describe 'normalize_attributes' do
    let(:user) { FactoryGirl.build(:user, phone: '773.83ddp+83(887)', email: "SOMethinG@example.com\n") }
    before(:each) { user.normalize_attributes }

    it 'strips the non-digit numbers from the phone input' do
      expect(user.phone).to eq('7738383887')
    end

    it 'normalizes the email' do
      expect(user.email).to eq('something@example.com')
    end
  end

  describe 'subscriptions' do
    it 'returns the payment if payment is subscription' do
      user = FactoryGirl.create(:user)
      Payment.create(is_recurring: true, user_id: user)
      expect(user.subscriptions).to eq(user.payments.where(is_recurring: true))
    end
  end

  describe 'userlink' do
    it 'returns user path if user show' do
      user = User.new(show_bikes: true, username: 'coolstuff')
      # pp user
      expect(user.userlink).to eq('/users/coolstuff')
    end

    it 'returns twitter if user twitter' do
      user = User.new(show_bikes: false, username: 'coolstuff', twitter: 'bikeindex')
      # pp user
      expect(user.userlink).to eq('https://twitter.com/bikeindex')
    end
  end

  describe 'primary_user_email' do
    it 'can not set a unconfirmed email to the primary email'
  end

  describe 'additional_emails=' do
    let(:user) { FactoryGirl.create(:confirmed_user) }
    before do
      expect(user.user_emails.count).to eq 1
    end
    context 'blank' do
      it 'does nothing' do
        expect do
          user.additional_emails = ' '
          user.save
        end.to change(UserEmail, :count).by 0
        expect(UserEmail.where(user_id: user.id).count).to eq 1
      end
    end
    context 'a single email' do
      it 'adds the email' do
        expect do
          user.additional_emails = 'stuffthings@oooooooooh.com'
          user.save
        end.to change(UserEmail, :count).by 1
        user.reload
        expect(user.user_emails.confirmed.count).to eq 1
        expect(user.user_emails.unconfirmed.count).to eq 1
        expect(user.user_emails.unconfirmed.first.email).to eq 'stuffthings@oooooooooh.com'
      end
    end
    context 'list with repeats' do
      it 'adds the non-duped emails' do
        user.additional_emails = 'stuffthings@oooooooooh.com,another_email@cool.com'
        user.save
        user.reload
        # pp user.user_emails
        # pp UserEmail.all
        expect(UserEmail.unconfirmed.where(user_id: user.id).count).to eq 2
        second_confirmed = UserEmail.where(user_id: user.id, email: 'stuffthings@oooooooooh.com').first
        second_confirmed.confirm(second_confirmed.confirmation_token)
        user.reload
        expect(user.user_emails.confirmed.count).to eq 2
        expect(user.user_emails.unconfirmed.count).to eq 1
        expect do
          user.additional_emails = ' andAnother@cool.com,stuffthings@oooooooooh.com,another_email@cool.com,lols@stuff.com'
          user.save
        end.to change(UserEmail, :count).by 2
        user.reload
        expect(user.user_emails.confirmed.count).to eq 2
        expect(user.user_emails.where(email: 'andanother@cool.com').count).to eq 1
      end
    end
  end

  describe 'is_member_of?' do
    let(:organization) { FactoryGirl.create(:organization) }
    context 'admin of organization' do
      let(:user) { FactoryGirl.create(:organization_admin, organization: organization) }
      it 'returns true' do
        expect(user.is_member_of?(organization)).to be_truthy
      end
    end
    context 'member of organization' do
      let(:user) { FactoryGirl.create(:organization_member, organization: organization) }
      it 'returns true' do
        expect(user.is_member_of?(organization)).to be_truthy
      end
    end
    context 'superadmin' do
      let(:user) { FactoryGirl.create(:admin) }
      it 'returns true' do
        expect(user.is_member_of?(organization)).to be_truthy
      end
    end
    context 'incorrect searching' do
      let(:user) { FactoryGirl.create(:organization_admin, organization: organization) }
      context 'non-member' do
        let(:other_organization) { FactoryGirl.create(:organization) }
        it 'returns false' do
          expect(other_organization).to be_present
          expect(user.is_member_of?(other_organization)).to be_falsey
        end
      end
      context 'no organization' do
        it 'returns false' do
          expect(user.is_member_of?(nil)).to be_falsey
        end
      end
    end
  end

  describe 'is_admin_of?' do
    let(:organization) { FactoryGirl.create(:organization) }
    context 'admin of organization' do
      let(:user) { FactoryGirl.create(:organization_admin, organization: organization) }
      it 'returns true' do
        expect(user.is_admin_of?(organization)).to be_truthy
      end
    end
    context 'member of organization' do
      let(:user) { FactoryGirl.create(:organization_member, organization: organization) }
      it 'returns true' do
        expect(user.is_admin_of?(organization)).to be_falsey
      end
    end
    context 'superadmin' do
      let(:user) { FactoryGirl.create(:admin) }
      it 'returns true' do
        expect(user.is_admin_of?(organization)).to be_truthy
      end
    end
    context 'incorrect searching' do
      let(:user) { FactoryGirl.create(:organization_admin, organization: organization) }
      context 'non-member' do
        let(:other_organization) { FactoryGirl.create(:organization) }
        it 'returns false' do
          expect(other_organization).to be_present
          expect(user.is_admin_of?(other_organization)).to be_falsey
        end
      end
      context 'no organization' do
        it 'returns false' do
          expect(user.is_admin_of?(nil)).to be_falsey
        end
      end
    end
  end
end
