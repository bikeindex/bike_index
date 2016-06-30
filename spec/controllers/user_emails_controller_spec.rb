require 'spec_helper'

describe UserEmailsController do
  let(:user_email) { FactoryGirl.create(:user_email, confirmation_token: 'sometoken-or-something') }
  let(:user) { user_email.user }
  before do
    expect(user_email.confirmed).to be_falsey
  end

  describe 'resend_confirmation' do
    context 'user who has user_email' do
      it 'enqueues a job to send an additional email confirmation' do
        set_current_user(user)
        expect do
          post :resend_confirmation, id: user_email.id
        end.to change(AdditionalEmailConfirmationWorker.jobs, :size).by 1
        expect(flash[:success]).to be_present
      end
    end

    context "not user's user_email" do
      it 'does not enqueue a job and sets the flash' do
        set_current_user(FactoryGirl.create(:confirmed_user))
        expect do
          post :resend_confirmation, id: user_email.id
        end.to change(AdditionalEmailConfirmationWorker.jobs, :size).by 0
        expect(flash[:error]).to match(/not your/)
      end
    end

    context 'no user, no email_id' do
      it 'does not enqueue a job and sets the flash (and does not break)' do
        expect do
          post :resend_confirmation, id: 33333
        end.to change(AdditionalEmailConfirmationWorker.jobs, :size).by 0
        expect(flash[:error]).to match(/not your/)
      end
    end
  end

  describe 'confirm' do
    context "user's user email" do
      before do
        set_current_user(user)
      end
      context 'unconfirmed' do
        it 'confirms and enqueues merge job' do
          expect do
            get :confirm, id: user_email.id, confirmation_token: user_email.confirmation_token
          end.to change(MergeAdditionalEmailWorker.jobs, :size).by 1
          user_email.reload
          expect(user_email.confirmed).to be_truthy
          expect(flash[:success]).to be_present
        end
      end
      context 'confirmed' do
        it 'sets flash info and does not add job' do
          user_email.confirm(user_email.confirmation_token)
          expect do
            get :confirm, id: user_email.id, confirmation_token: 'sometoken-or-something'
          end.to change(MergeAdditionalEmailWorker.jobs, :size).by 0
          expect(flash[:info]).to be_present
        end
      end
      context 'incorrect token' do
        it 'sets flash error and does not add job' do
          expect do
            get :confirm, id: user_email.id, confirmation_token: 'somethingelse-'
          end.to change(MergeAdditionalEmailWorker.jobs, :size).by 0
          expect(flash[:error]).to be_present
        end
      end
    end

    context "not user's user_email" do
      it 'does not enqueue a job and sets the flash' do
        set_current_user(FactoryGirl.create(:confirmed_user))
        expect do
          get :confirm, id: user_email.id, confirmation_token: user_email.confirmation_token
        end.to change(AdditionalEmailConfirmationWorker.jobs, :size).by 0
        expect(flash[:error]).to match(/not your/)
      end
    end

    context 'no user, no email_id' do
      it 'does not enqueue a job and sets the flash (and does not break)' do
        expect do
          get :confirm, id: user_email.id, confirmation_token: user_email.confirmation_token
        end.to change(AdditionalEmailConfirmationWorker.jobs, :size).by 0
        expect(flash[:error]).to match(/not your/)
      end
    end
  end


  describe 'destroy' do
    context "user's user email" do
      before do
        set_current_user(user)
      end
      context 'unconfirmed' do
        it 'deletes the email' do
          delete :destroy, id: user_email.id
          expect(UserEmail.where(id: user_email.id)).to_not be_present
          expect(flash[:success]).to be_present
        end
      end
      context 'confirmed' do
        it 'sets flash info and does not delete the email' do
          user_email.confirm(user_email.confirmation_token)
          delete :destroy, id: user_email.id
          user_email.reload
          expect(user_email).to be_present
          expect(flash[:info]).to be_present
        end
      end
    end

    context "not user's user_email" do
      it 'does not delete the email and sets an error flash' do
        set_current_user(FactoryGirl.create(:confirmed_user))
        expect do
          delete :destroy, id: user_email.id
        end.to change(AdditionalEmailConfirmationWorker.jobs, :size).by 0
        expect(flash[:error]).to match(/not your/)
      end
    end

    context 'no user, no email_id' do
      it 'does not delete the email and sets an error flash' do
        expect do
          delete :destroy, id: user_email.id
        end.to change(AdditionalEmailConfirmationWorker.jobs, :size).by 0
        expect(flash[:error]).to match(/not your/)
      end
    end
  end

  describe 'make_primary' do
    context "user's user email" do
      before do
        set_current_user(user)
      end
      context 'unconfirmed' do
        it 'does not make primary' do
          post :make_primary, id: user_email.id
          user_email.reload
          expect(user_email.primary).to be_falsey
          expect(user_email.confirmed).to be_falsey
          expect(flash[:info]).to be_present
        end
      end
      context 'confirmed' do
        it 'sets flash success and makes primary' do
          user_email.confirm(user_email.confirmation_token)
          expect(user.user_emails.confirmed.count).to eq 2
          post :make_primary, id: user_email.id
          user_email.reload
          user.reload
          expect(user_email.primary).to be_truthy
          expect(user_email.confirmed).to be_truthy
          expect(user.email).to eq user_email.email
          expect(flash[:success]).to be_present
        end
      end
      context 'confirmed and primary' do
        it 'user_email remains primary' do
          user_email.confirm(user_email.confirmation_token)
          user_email.make_primary
          post :make_primary, id: user_email.id
          user_email.reload
          expect(user_email.primary).to be_truthy
        end
      end
    end

    context "not user's user_email" do
      it 'does not enqueue a job and sets the flash' do
        set_current_user(FactoryGirl.create(:confirmed_user))
        post :make_primary, id: user_email.id
        user_email.reload
        expect(user_email.primary).to be_falsey
        expect(flash[:error]).to match(/not your/)
      end
    end

    context 'no user, no email_id' do
      it 'does not enqueue a job and sets the flash (and does not break)' do
        post :make_primary, id: user_email.id
        user_email.reload
        expect(user_email.primary).to be_falsey
        expect(flash[:error]).to match(/not your/)
      end
    end
  end
end
