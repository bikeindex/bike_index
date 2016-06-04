require 'spec_helper'

describe UserEmail do
  describe 'validations' do
    it { is_expected.to belong_to(:user).touch(true) }
    it { is_expected.to belong_to :old_user }
    it { is_expected.to validate_presence_of :user_id }
    it { is_expected.to validate_presence_of :email }
  end

  describe 'scopes' do
    it 'confirmed only user_emails without tokens' do
      expect(UserEmail.confirmed.to_sql).to eq(UserEmail.where('confirmation_token IS NULL').to_sql)
    end
    it 'unconfirmed scopes to only unconfirmed UserEmails' do
      expect(UserEmail.unconfirmed.to_sql).to eq(UserEmail.where('confirmation_token IS NOT NULL').to_sql)
    end
  end

  describe 'create_confirmed_primary_email' do
    context 'confirmed user' do
      let(:user) { User.new(email: 'cool@stuff.com') }
      it 'creates a new user_email' do
        user.confirmed = true
        user.id = 4444
        user_email = UserEmail.create_confirmed_primary_email(user)
        expect(user_email.confirmed).to be_truthy
        expect(user_email.email).to eq 'cool@stuff.com'
        expect(user_email.valid?).to be_truthy
      end
    end
    context 'already existing' do
      let(:user) { FactoryGirl.create(:confirmed_user, email: 'cool@stuff.com') }
      it 'creates a new user_email' do
        expect(user.confirmed).to be_truthy
        expect(user.user_emails.count).to eq 1
        user_email = user.user_emails.first
        expect do
          expect(UserEmail.create_confirmed_primary_email(user)).to eq user_email
        end.to change(UserEmail, :count).by 0
      end
    end
  end

  describe 'fuzzy_user_id_find' do
    let(:user) { FactoryGirl.create(:confirmed_user, email: 'mommy@stuff.com') }
    before do
      expect(user).to be_present
    end
    context 'blank' do
      it 'returns nil' do
        expect(UserEmail.fuzzy_user_id_find(' ')).to be_nil
      end
    end
    context 'matching' do
      it 'returns the user' do
        expect(UserEmail.fuzzy_user_id_find('mommy@stUFF.com ')).to eq user.id
      end
    end
    context 'non-matching' do
      it 'returns nil' do
        expect(UserEmail.fuzzy_user_id_find('something@fooooOO.edu')).to be_nil
      end
    end
  end

  describe 'fuzzy_user_find' do
    let(:user) { FactoryGirl.create(:confirmed_user, email: 'mommy@stuff.com') }
    before do
      expect(user).to be_present
    end
    context 'blank' do
      it 'returns nil' do
        expect(UserEmail.fuzzy_user_find(' ')).to be_nil
      end
    end
    context 'matching' do
      it 'returns the user' do
        expect(UserEmail.fuzzy_user_find('mommy@stUFF.com ')).to eq user
      end
    end
    context 'non-matching' do
      it 'returns nil' do
        expect(UserEmail.fuzzy_user_find('something@fooooOO.edu')).to be_nil
      end
    end
  end

  
end
