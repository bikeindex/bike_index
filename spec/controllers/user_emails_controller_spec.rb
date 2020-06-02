require "rails_helper"

RSpec.describe UserEmailsController, type: :controller do
  let(:user_email) { FactoryBot.create(:user_email, confirmation_token: "sometoken-or-something") }
  let(:user) { user_email.user }

  describe "resend_confirmation" do
    before { expect(user_email.confirmed?).to be_falsey }
    context "user who has user_email" do
      it "enqueues a job to send an additional email confirmation" do
        set_current_user(user)
        expect do
          post :resend_confirmation, params: { id: user_email.id }
        end.to change(AdditionalEmailConfirmationWorker.jobs, :size).by 1
        expect(flash[:success]).to be_present
      end
    end

    context "not user's user_email" do
      it "does not enqueue a job and sets the flash" do
        set_current_user(FactoryBot.create(:user_confirmed))
        expect do
          post :resend_confirmation, params: { id: user_email.id }
        end.to change(AdditionalEmailConfirmationWorker.jobs, :size).by 0
        expect(flash[:error]).to match(/signed in with primary email/)
      end
    end

    context "no user, no email_id" do
      it "does not enqueue a job and sets the flash (and does not break)" do
        expect do
          post :resend_confirmation, params: { id: 33333 }
        end.to change(AdditionalEmailConfirmationWorker.jobs, :size).by 0
        expect(flash[:error]).to match(/signed in with primary email/)
      end
    end
  end

  describe "confirm" do
    context "user's user email" do
      before do
        set_current_user(user)
        expect(user_email.confirmed?).to be_falsey
      end
      context "unconfirmed" do
        it "confirms and enqueues merge job" do
          expect do
            get :confirm, params: { id: user_email.id, confirmation_token: user_email.confirmation_token }
          end.to change(MergeAdditionalEmailWorker.jobs, :size).by 1
          user_email.reload
          expect(user_email.confirmed?).to be_truthy
          expect(flash[:success]).to be_present
        end
      end
      context "confirmed" do
        it "sets flash info and does not add job" do
          user_email.confirm(user_email.confirmation_token)
          expect do
            get :confirm, params: { id: user_email.id, confirmation_token: "sometoken-or-something" }
          end.to change(MergeAdditionalEmailWorker.jobs, :size).by 0
          expect(flash[:info]).to be_present
        end
      end
      context "incorrect token" do
        it "sets flash error and does not add job" do
          expect do
            get :confirm, params: { id: user_email.id, confirmation_token: "somethingelse-" }
          end.to change(MergeAdditionalEmailWorker.jobs, :size).by 0
          expect(flash[:error]).to be_present
        end
      end
    end

    context "not user's user_email" do
      it "does not enqueue a job and sets the flash" do
        set_current_user(FactoryBot.create(:user_confirmed))
        expect do
          get :confirm, params: { id: user_email.id, confirmation_token: user_email.confirmation_token }
        end.to change(AdditionalEmailConfirmationWorker.jobs, :size).by 0
        expect(flash[:error]).to match(/signed in with primary email/)
      end
    end

    context "no user, no email_id" do
      it "does not enqueue a job and sets the flash (and does not break)" do
        expect do
          get :confirm, params: { id: user_email.id, confirmation_token: user_email.confirmation_token }
        end.to change(AdditionalEmailConfirmationWorker.jobs, :size).by 0
        expect(flash[:error]).to match(/signed in with primary email/)
      end
    end
  end

  describe "destroy" do
    context "user's user email" do
      let(:user) { FactoryBot.create(:user_confirmed) }
      let(:user_email_primary) { user.user_emails.first }
      let!(:user_email1) { FactoryBot.create(:user_email, user: user, confirmation_token: "sometoken") }
      before { set_current_user(user) }
      context "unconfirmed" do
        it "deletes the email" do
          expect(user_email1.confirmed?).to be_falsey
          expect(user.user_emails.count).to eq 2
          delete :destroy, params: { id: user_email1.id }
          expect(UserEmail.where(id: user_email1.id)).to_not be_present
          expect(flash[:success]).to be_present
        end
      end
      context "only email, not confirmed" do
        it "sets flash info and does not delete the email" do
          expect(user_email1.confirmed?).to be_falsey
          user_email_primary.destroy
          user.reload
          expect(user.user_emails.count).to eq 1
          expect(user.user_emails.confirmed.count).to eq 0
          expect do
            delete :destroy, params: { id: user.user_emails.first.id }
          end.to_not change(UserEmail, :count)
          user.reload
          expect(user.user_emails.confirmed.count).to eq 0
          expect(user.user_emails.count).to eq 1
          expect(flash[:info]).to be_present
        end
      end
      context "multiple confirmed" do
        let!(:user_email1) { FactoryBot.create(:user_email, user: user, confirmation_token: nil) }
        it "permits deleting" do
          user.reload
          user_email1.reload
          expect(user.user_emails.count).to eq 2
          expect(user.user_emails.confirmed.count).to eq 2
          expect(user_email1.primary?).to be_falsey
          expect(user_email_primary.primary?).to be_truthy
          expect do
            delete :destroy, params: { id: user_email1.id }
          end.to change(UserEmail, :count).by(-1)
          expect(flash[:success]).to be_present
          expect(UserEmail.where(id: user_email1.id)).to_not be_present
          user.reload
          user_email_primary.reload
          expect(user.user_emails.confirmed.count).to eq 1
          expect(user_email_primary.primary?).to be_truthy
        end
        context "delete primary" do
          it "sets flash info and does not delete the email" do
            expect(user_email1.confirmed?).to be_truthy
            expect(user.user_emails.confirmed.count).to eq 2
            expect do
              delete :destroy, params: { id: user_email_primary.id }
            end.to_not change(UserEmail, :count)
            expect(flash[:info]).to be_present
            user.reload
            user_email_primary.reload
            expect(user_email_primary).to be_present
            expect(user.user_emails.confirmed.count).to eq 2
          end
        end
      end
    end

    context "not user's user_email" do
      it "does not delete the email and sets an error flash" do
        set_current_user(FactoryBot.create(:user_confirmed))
        expect do
          delete :destroy, params: { id: user_email.id }
        end.to change(AdditionalEmailConfirmationWorker.jobs, :size).by 0
        expect(flash[:error]).to match(/signed in with primary email/)
      end
    end

    context "no user, no email_id" do
      it "does not delete the email and sets an error flash" do
        expect do
          delete :destroy, params: { id: user_email.id }
        end.to change(AdditionalEmailConfirmationWorker.jobs, :size).by 0
        expect(flash[:error]).to match(/signed in with primary email/)
      end
    end
  end

  describe "make_primary" do
    context "user's user email" do
      before do
        set_current_user(user)
      end
      context "unconfirmed" do
        it "does not make primary" do
          post :make_primary, params: { id: user_email.id }
          user_email.reload
          expect(user_email.primary?).to be_falsey
          expect(user_email.confirmed?).to be_falsey
          expect(flash[:info]).to be_present
        end
      end
      context "confirmed" do
        it "sets flash success and makes primary" do
          user_email.confirm(user_email.confirmation_token)
          expect(user.user_emails.confirmed.count).to eq 2
          post :make_primary, params: { id: user_email.id }
          user_email.reload
          user.reload
          expect(user_email.primary?).to be_truthy
          expect(user_email.confirmed?).to be_truthy
          expect(user.email).to eq user_email.email
          expect(flash[:success]).to be_present
        end
      end
      context "confirmed and primary" do
        it "user_email remains primary" do
          user_email.confirm(user_email.confirmation_token)
          user_email.make_primary
          post :make_primary, params: { id: user_email.id }
          user_email.reload
          expect(user_email.primary?).to be_truthy
        end
      end
    end

    context "not user's user_email" do
      it "does not enqueue a job and sets the flash" do
        set_current_user(FactoryBot.create(:user_confirmed))
        post :make_primary, params: { id: user_email.id }
        user_email.reload
        expect(user_email.primary?).to be_falsey
        expect(flash[:error]).to match(/signed in with primary email/)
      end
    end

    context "no user, no email_id" do
      it "does not enqueue a job and sets the flash (and does not break)" do
        post :make_primary, params: { id: user_email.id }
        user_email.reload
        expect(user_email.primary?).to be_falsey
        expect(flash[:error]).to match(/signed in with primary email/)
      end
    end
  end
end
