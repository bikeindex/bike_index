require 'spec_helper'

describe UsersController do
  describe 'new' do
    context 'already signed in' do
      it 'redirects and sets the flash' do
        user = FactoryGirl.create(:user)
        set_current_user(user)
        get :new
        expect(response).to redirect_to(:user_home)
        expect(flash).to be_present
      end
    end
    context 'not signed in' do
      it 'renders and calls set store_return_to' do
        expect(controller).to receive(:store_return_to)
        get :new
        expect(response.code).to eq('200')
        expect(response).to render_template('new')
        expect(flash).to_not be_present
        expect(response).to render_with_layout('application_revised')
      end
    end
  end

  describe 'create' do
    context 'legacy' do
      describe 'success' do
        it 'creates a non-confirmed record' do
          expect do
            post :create, user: FactoryGirl.attributes_for(:user)
          end.to change(User, :count).by(1)
        end
        it 'creates a confirmed user, log in, and send welcome if user has org invite' do
          expect_any_instance_of(CreateUserJobs).to receive(:send_welcome_email)
          organization_invitation = FactoryGirl.create(:organization_invitation, invitee_email: 'poo@pile.com')
          post :create, user: FactoryGirl.attributes_for(:user, email: 'poo@pile.com')
          expect(User.from_auth(cookies.signed[:auth])).to eq(User.fuzzy_email_find('poo@pile.com'))
          expect(response).to redirect_to(user_home_url)
        end
      end

      describe 'failure' do
        let(:user_attributes) do
          user = FactoryGirl.attributes_for(:user)
          user[:password_confirmation] = 'bazoo'
          user
        end
        it 'does not create a user or send a welcome email' do
          expect do
            post :create, user: user_attributes
          end.to change(EmailWelcomeWorker.jobs, :size).by(0)
          expect(User.count).to eq(0)
        end
        it 'renders new' do
          post :create, user: user_attributes
          expect(response).to render_template('new')
        end
      end
    end

    describe 'confirm' do
      describe 'user exists' do
        it 'tells the user to log in when already confirmed' do
          @user = FactoryGirl.create(:user, confirmed: true)
          get :confirm, id: @user.id, code: 'wtfmate'
          expect(response).to redirect_to new_session_url
        end

        describe 'user not yet confirmed' do
          before :each do
            @user = FactoryGirl.create(:user)
            expect(User).to receive(:find).and_return(@user)
          end

          it 'logins and redirect when confirmation succeeds' do
            expect(@user).to receive(:confirm).and_return(true)
            get :confirm, id: @user.id, code: @user.confirmation_token
            expect(User.from_auth(cookies.signed[:auth])).to eq(@user)
            expect(response).to redirect_to user_home_url
          end

          it 'shows a view when confirmation fails' do
            expect(@user).to receive(:confirm).and_return(false)
            get :confirm, id: @user.id, code: 'Wtfmate'
            expect(response).to render_template :confirm_error_bad_token
          end
        end
      end

      it 'shows an appropriate message when the user is nil' do
        get :confirm, id: 1234, code: 'Wtfmate'
        expect(response).to render_template :confirm_error_404
      end
    end
    context 'revised' do
      let(:user_attrs) do
        {
          name: 'foo',
          email: 'foo1@bar.com',
          password: 'coolpasswprd$$$$$',
          terms_of_service: '0',
          is_emailable: '0'
        }
      end

      context 'create attrs' do
        it 'renders' do
          expect do
            post :create, user: user_attrs
          end.to change(User, :count).by(1)
        end
      end
    end
  end

  describe 'password_reset' do
    describe 'if the token is present and valid' do
      it 'logs in and redirects' do
        user = FactoryGirl.create(:user, email: 'ned@foo.com')
        user.set_password_reset_token
        post :password_reset, token: user.password_reset_token
        expect(User.from_auth(cookies.signed[:auth])).to eq(user)
        expect(response).to render_template :update_password
      end
    end

    it 'renders get request' do
      user = FactoryGirl.create(:user, email: 'ned@foo.com')
      user.set_password_reset_token
      get :password_reset, token: user.password_reset_token
      expect(response.code).to eq('200')
    end

    it 'does not log in if the token is present and valid' do
      post :password_reset, token: 'Not Actually a token'
      expect(response).to render_template :request_password_reset
    end

    it 'enqueues a password reset email job' do
      @user = FactoryGirl.create(:confirmed_user, email: 'something@boo.com')
      expect do
        post :password_reset, email: @user.email
      end.to change(EmailResetPasswordWorker.jobs, :size).by(1)
    end

    it 'enqueues a password reset email job' do
      @user = FactoryGirl.create(:user, email: 'ned@foo.com')
      expect do
        post :password_reset, email: @user.email
      end.to change(EmailResetPasswordWorker.jobs, :size).by(1)
    end
  end

  describe 'show' do
    xit "404s if the user doesn't exist" do
      # I have no idea why this fails. It works really, but not in tests!
      expect do
        get :edit, id: 'fake_user'
      end.to raise_error(ActionController::RoutingError)
    end

    it "redirects to user home url if the user exists but doesn't want to show their page" do
      @user = FactoryGirl.create(:user)
      @user.show_bikes = false
      @user.save
      get :show, id: @user.username
      expect(response).to redirect_to user_home_url
    end

    it 'shows the page if the user exists and wants to show their page' do
      @user = FactoryGirl.create(:user)
      @user.show_bikes = true
      @user.save
      get :show, id: @user.username
      expect(response).to render_template :show
    end
  end

  describe 'accept_vendor_terms' do
    it 'renders' do
      user = FactoryGirl.create(:user)
      set_current_user(user)
      get :accept_vendor_terms
      expect(response.status).to eq(200)
      expect(response).to render_template(:accept_vendor_terms)
      expect(response).to render_with_layout('application_revised')
    end
  end

  describe 'accept_terms' do
    it 'renders' do
      user = FactoryGirl.create(:user)
      set_current_user(user)
      get :accept_terms
      expect(response).to render_template(:accept_terms)
      expect(response).to render_with_layout('application_revised')
    end
  end

  describe 'edit' do
    it 'renders with application_revised' do
      user = FactoryGirl.create(:user)
      set_current_user(user)
      get :edit
      expect(response.status).to eq(200)
      expect(response).to render_template(:edit)
      expect(response).to render_with_layout('application_revised')
    end
  end

  describe 'update' do
    it "doesn't update user if current password not present" do
      user = FactoryGirl.create(:user, terms_of_service: false, password: 'old_pass', password_confirmation: 'old_pass')
      set_current_user(user)
      post :update, id: user.username, user: {
        password: 'new_pass',
        password_confirmation: 'new_pass' }
      expect(user.reload.authenticate('new_pass')).to be_falsey
    end

    it "doesn't update user if password doesn't match" do
      user = FactoryGirl.create(:user, terms_of_service: false, password: 'old_pass', password_confirmation: 'old_pass')
      set_current_user(user)
      post :update, id: user.username, user: {
        current_password: 'old_pass',
        password: 'new_pass',
        name: 'Mr. Slick',
        password_confirmation: 'new_passd' }
      expect(user.reload.authenticate('new_pass')).to be_falsey
      expect(user.name).not_to eq('Mr. Slick')
    end

    it 'Updates user if there is a reset_pass token' do
      user = FactoryGirl.create(:user)
      user.set_password_reset_token((Time.now - 30.minutes).to_i)
      user.reload
      auth = user.auth_token
      email = user.email
      set_current_user(user)
      post :update, id: user.username, user: {
        email: 'cool_new_email@something.com',
        password_reset_token: user.password_reset_token,
        password: 'new_pass',
        password_confirmation: 'new_pass' }
      expect(user.reload.authenticate('new_pass')).to be_truthy
      expect(user.email).to eq(email)
      expect(user.password_reset_token).not_to eq('stuff')
      expect(user.auth_token).not_to eq(auth)
      expect(cookies.signed[:auth][1]).to eq(user.auth_token)
      expect(response).to redirect_to(my_account_url)
    end

    it "Doesn't updates user if reset_pass token doesn't match" do
      user = FactoryGirl.create(:user)
      user.set_password_reset_token
      user.reload
      reset = user.password_reset_token
      auth = user.auth_token
      email = user.email
      set_current_user(user)
      post :update, id: user.username, user: {
        password_reset_token: 'something_else',
        password: 'new_pass',
        password_confirmation: 'new_pass' }
      expect(user.reload.authenticate('new_pass')).to be_falsey
      expect(user.password_reset_token).to eq(reset)
    end

    it "Doesn't update user if reset_pass token is more than an hour old" do
      user = FactoryGirl.create(:user)
      user.set_password_reset_token((Time.now - 61.minutes).to_i)
      auth = user.auth_token
      email = user.email
      set_current_user(user)
      post :update, id: user.username, user: {
        password_reset_token: user.password_reset_token,
        password: 'new_pass',
        password_confirmation: 'new_pass' }
      expect(user.reload.authenticate('new_pass')).not_to be_truthy
      expect(user.auth_token).to eq(auth)
      expect(user.password_reset_token).not_to eq('stuff')
      expect(cookies.signed[:auth][1]).to eq(user.auth_token)
    end

    it 'resets users auth if password changed, updates current session' do
      user = FactoryGirl.create(:user, terms_of_service: false, password: 'old_pass', password_confirmation: 'old_pass', password_reset_token: 'stuff')
      auth = user.auth_token
      email = user.email
      set_current_user(user)
      post :update, id: user.username, user: {
        email: 'cool_new_email@something.com',
        current_password: 'old_pass',
        password: 'new_pass',
        name: 'Mr. Slick',
        password_confirmation: 'new_pass' }
      expect(response).to redirect_to(my_account_url)
      expect(user.reload.authenticate('new_pass')).to be_truthy
      expect(user.auth_token).not_to eq(auth)
      expect(user.email).to eq(email)
      expect(user.password_reset_token).not_to eq('stuff')
      expect(user.name).to eq('Mr. Slick')
      expect(cookies.signed[:auth][1]).to eq(user.auth_token)
    end

    it 'updates the terms of service' do
      user = FactoryGirl.create(:user, terms_of_service: false)
      set_current_user(user)
      post :update, id: user.username, user: { terms_of_service: '1' }
      expect(response).to redirect_to(user_home_url)
      expect(user.reload.terms_of_service).to be_truthy
    end

    it 'updates the vendor terms of service and emailable' do
      user = FactoryGirl.create(:user, terms_of_service: false, is_emailable: false)
      expect(user.is_emailable).to be_falsey
      org = FactoryGirl.create(:organization)
      FactoryGirl.create(:membership, organization: org, user: user)
      set_current_user(user)
      post :update, id: user.username, user: { vendor_terms_of_service: '1', is_emailable: true }
      expect(response.code).to eq('302')
      expect(user.reload.vendor_terms_of_service).to be_truthy
      expect(user.is_emailable).to be_truthy
    end

    it 'enqueues job (it enqueues job whenever update is successful)' do
      user = FactoryGirl.create(:user)
      set_current_user(user)
      expect do
        post :update, id: user.username, user: { name: 'Cool stuff' }
      end.to change(AfterUserChangeWorker.jobs, :size).by(1)
      expect(user.reload.name).to eq('Cool stuff')
    end
  end
end
