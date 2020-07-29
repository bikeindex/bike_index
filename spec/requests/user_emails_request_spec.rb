require "rails_helper"

RSpec.describe UserEmailsController, type: :request do
  base_url = "/user_emails"
  let(:user_email) { FactoryBot.create(:user_email, confirmation_token: "sometoken-or-something", email: "new_email@example.com") }
  let(:current_user) { user_email.user }

  describe "resend_confirmation" do
    before { expect(user_email.confirmed?).to be_falsey }
    context "user who has user_email" do
      it "enqueues a job to send an additional email confirmation" do
        log_in(current_user)
        expect {
          post "#{base_url}/#{user_email.id}/resend_confirmation"
        }.to change(AdditionalEmailConfirmationWorker.jobs, :size).by 1
        expect(flash[:success]).to be_present
      end
    end

    context "not user's user_email" do
      it "does not enqueue a job and sets the flash" do
        log_in(FactoryBot.create(:user_confirmed))
        expect {
          post "#{base_url}/#{user_email.id}/resend_confirmation"
        }.to change(AdditionalEmailConfirmationWorker.jobs, :size).by 0
        expect(flash[:error]).to match(/signed in with primary email/)
      end
    end

    context "no user, no email_id" do
      it "does not enqueue a job and sets the flash (and does not break)" do
        expect {
          post "#{base_url}/33333/resend_confirmation"
        }.to change(AdditionalEmailConfirmationWorker.jobs, :size).by 0
        expect(flash[:error]).to match(/signed in with primary email/)
      end
    end
  end

  describe "confirm" do
    context "user's user email" do
      before do
        log_in(current_user)
        expect(user_email.confirmed?).to be_falsey
      end
      context "unconfirmed" do
        it "confirms and enqueues merge job" do
          expect {
            get "#{base_url}/#{user_email.id}/confirm?confirmation_token=#{user_email.confirmation_token}"
          }.to change(MergeAdditionalEmailWorker.jobs, :size).by 1
          user_email.reload
          expect(user_email.confirmed?).to be_truthy
          expect(flash[:success]).to be_present
        end
        context "process merge" do
          let(:state) { FactoryBot.create(:state, name: "Colorado", abbreviation: "CO", country: Country.united_states) }
          let!(:membership) { FactoryBot.create(:membership, invited_email: "new_email@example.com") }
          let(:bike) { FactoryBot.create(:bike, street: "123 main street", city: "Denver", state: state, country: Country.united_states) }
          let!(:ownership) { FactoryBot.create(:ownership, owner_email: "new_email@example.com", bike: bike, creator: bike.creator) }
          let!(:appointment) { FactoryBot.create(:appointment, email: "new_email@example.com") }
          let(:b_param) { FactoryBot.create(:b_param, created_bike: bike, params: {bike: {phone: "888.883.3232"}}) }
          it "assigns the things" do
            expect(b_param.creator.id).to eq bike.creator.id
            expect(user_email.confirmed?).to be_falsey
            expect(membership.claimed?).to be_falsey
            expect(ownership.claimed?).to be_falsey
            expect(appointment.claimed?).to be_falsey
            expect(b_param.created_bike).to eq bike
            expect(b_param.phone).to eq "8888833232"
            bike.reload
            expect(bike.first_ownership?).to be_truthy
            expect(bike.b_params.pluck(:id)).to eq([b_param.id])
            expect(bike.phone).to eq "8888833232"
            Sidekiq::Worker.clear_all
            Sidekiq::Testing.inline! do
              get "#{base_url}/#{user_email.id}/confirm?confirmation_token=#{user_email.confirmation_token}"
            end
            expect(flash[:success]).to be_present
            expect(response).to redirect_to edit_my_account_path
            user_email.reload
            expect(user_email.confirmed?).to be_truthy
            current_user.reload
            expect(current_user.secondary_emails).to eq(["new_email@example.com"])
            expect(current_user.memberships.pluck(:id)).to eq([membership.id])
            expect(current_user.ownerships.pluck(:id)).to eq([ownership.id])
            expect(current_user.appointments.pluck(:id)).to eq([appointment.id])
            expect(current_user.phone).to eq "8888833232"
            expect(current_user.street).to eq "123 main street"
            expect(current_user.city).to eq "Denver"
            expect(current_user.state).to eq state
            expect(current_user.country).to eq Country.united_states
          end

          context "with existing user" do
            let(:old_user) { FactoryBot.create(:user_confirmed, email: "new_email@example.com") }
            let!(:membership) { FactoryBot.create(:membership_claimed, user: old_user) }
            let!(:ownership) { FactoryBot.create(:ownership_claimed, user: old_user, bike: bike) }
            let!(:appointment) { FactoryBot.create(:appointment, :claimed, user: old_user) }
            it "assigns the things" do
              expect(user_email.confirmed?).to be_falsey
              expect(membership.claimed?).to be_truthy
              expect(ownership.claimed?).to be_truthy
              expect(appointment.claimed?).to be_truthy
              expect(bike.user).to eq old_user
              Sidekiq::Worker.clear_all
              Sidekiq::Testing.inline! do
                get "#{base_url}/#{user_email.id}/confirm?confirmation_token=#{user_email.confirmation_token}"
              end
              expect(flash[:success]).to be_present
              expect(response).to redirect_to edit_my_account_path
              user_email.reload
              expect(user_email.confirmed?).to be_truthy
              expect(User.where(id: old_user.id).pluck(:id)).to eq([])
              current_user.reload
              expect(current_user.secondary_emails).to eq(["new_email@example.com"])
              expect(current_user.memberships.pluck(:id)).to eq([membership.id])
              expect(current_user.ownerships.pluck(:id)).to eq([ownership.id])
              expect(current_user.appointments.pluck(:id)).to eq([appointment.id])
              expect(current_user.street).to eq "123 main street"
              expect(current_user.city).to eq "Denver"
              expect(current_user.state).to eq state
              expect(current_user.country).to eq Country.united_states
            end
          end
        end
      end
      context "confirmed" do
        it "sets flash info and does not add job" do
          user_email.confirm(user_email.confirmation_token)
          expect {
            get "#{base_url}/#{user_email.id}/confirm?confirmation_token=sometoken-or-something"
          }.to change(MergeAdditionalEmailWorker.jobs, :size).by 0
          expect(flash[:info]).to be_present
        end
      end
      context "incorrect token" do
        it "sets flash error and does not add job" do
          expect {
            get "#{base_url}/#{user_email.id}/confirm?confirmation_token=somethingelse-"
          }.to change(MergeAdditionalEmailWorker.jobs, :size).by 0
          expect(flash[:error]).to be_present
        end
      end
    end

    context "not user's user_email" do
      it "does not enqueue a job and sets the flash" do
        log_in(FactoryBot.create(:user_confirmed))
        expect {
          get "#{base_url}/#{user_email.id}/confirm?confirmation_token=#{user_email.confirmation_token}"
        }.to change(AdditionalEmailConfirmationWorker.jobs, :size).by 0
        expect(flash[:error]).to match(/signed in with primary email/)
      end
    end

    context "no user, no email_id" do
      it "does not enqueue a job and sets the flash (and does not break)" do
        expect {
          get "#{base_url}/#{user_email.id}/confirm?confirmation_token=#{user_email.confirmation_token}"
        }.to change(AdditionalEmailConfirmationWorker.jobs, :size).by 0
        expect(flash[:error]).to match(/signed in with primary email/)
      end
    end
  end

  describe "destroy" do
    context "user's user email" do
      let(:current_user) { FactoryBot.create(:user_confirmed) }
      let(:user_email_primary) { current_user.user_emails.first }
      let!(:user_email1) { FactoryBot.create(:user_email, user: current_user, confirmation_token: "sometoken") }
      before { log_in(current_user) }
      context "unconfirmed" do
        it "deletes the email" do
          expect(user_email1.confirmed?).to be_falsey
          expect(current_user.user_emails.count).to eq 2
          delete "#{base_url}/#{user_email1.id}"
          expect(UserEmail.where(id: user_email1.id)).to_not be_present
          expect(flash[:success]).to be_present
        end
      end
      context "only email, not confirmed" do
        it "sets flash info and does not delete the email" do
          expect(user_email1.confirmed?).to be_falsey
          user_email_primary.destroy
          current_user.reload
          expect(current_user.user_emails.count).to eq 1
          expect(current_user.user_emails.confirmed.count).to eq 0
          expect {
            delete "#{base_url}/#{current_user.user_emails.first.id}"
          }.to_not change(UserEmail, :count)
          current_user.reload
          expect(current_user.user_emails.confirmed.count).to eq 0
          expect(current_user.user_emails.count).to eq 1
          expect(flash[:info]).to be_present
        end
      end
      context "multiple confirmed" do
        let!(:user_email1) { FactoryBot.create(:user_email, user: current_user, confirmation_token: nil) }
        it "permits deleting" do
          current_user.reload
          user_email1.reload
          expect(current_user.user_emails.count).to eq 2
          expect(current_user.user_emails.confirmed.count).to eq 2
          expect(user_email1.primary?).to be_falsey
          expect(user_email_primary.primary?).to be_truthy
          expect {
            delete "#{base_url}/#{user_email1.id}"
          }.to change(UserEmail, :count).by(-1)
          expect(flash[:success]).to be_present
          expect(UserEmail.where(id: user_email1.id)).to_not be_present
          current_user.reload
          user_email_primary.reload
          expect(current_user.user_emails.confirmed.count).to eq 1
          expect(user_email_primary.primary?).to be_truthy
        end
        context "delete primary" do
          it "sets flash info and does not delete the email" do
            expect(user_email1.confirmed?).to be_truthy
            expect(current_user.user_emails.confirmed.count).to eq 2
            expect {
              delete "#{base_url}/#{user_email_primary.id}"
            }.to_not change(UserEmail, :count)
            expect(flash[:info]).to be_present
            current_user.reload
            user_email_primary.reload
            expect(user_email_primary).to be_present
            expect(current_user.user_emails.confirmed.count).to eq 2
          end
        end
      end
    end

    context "not user's user_email" do
      it "does not delete the email and sets an error flash" do
        log_in(FactoryBot.create(:user_confirmed))
        expect {
          delete "#{base_url}/#{user_email.id}"
        }.to change(AdditionalEmailConfirmationWorker.jobs, :size).by 0
        expect(flash[:error]).to match(/signed in with primary email/)
      end
    end

    context "no user, no email_id" do
      it "does not delete the email and sets an error flash" do
        expect {
          delete "#{base_url}/#{user_email.id}"
        }.to change(AdditionalEmailConfirmationWorker.jobs, :size).by 0
        expect(flash[:error]).to match(/signed in with primary email/)
      end
    end
  end

  describe "make_primary" do
    context "user's user email" do
      before { log_in(current_user) }
      context "unconfirmed" do
        it "does not make primary" do
          post "#{base_url}/#{user_email.id}/make_primary"
          user_email.reload
          expect(user_email.primary?).to be_falsey
          expect(user_email.confirmed?).to be_falsey
          expect(flash[:info]).to be_present
        end
      end
      context "confirmed" do
        it "sets flash success and makes primary" do
          user_email.confirm(user_email.confirmation_token)
          expect(current_user.user_emails.confirmed.count).to eq 2
          post "#{base_url}/#{user_email.id}/make_primary"
          user_email.reload
          current_user.reload
          expect(user_email.primary?).to be_truthy
          expect(user_email.confirmed?).to be_truthy
          expect(current_user.email).to eq "new_email@example.com"
          expect(flash[:success]).to be_present
        end
      end
      context "confirmed and primary" do
        it "user_email remains primary" do
          user_email.confirm(user_email.confirmation_token)
          user_email.make_primary
          post "#{base_url}/#{user_email.id}/make_primary"
          user_email.reload
          expect(user_email.primary?).to be_truthy
        end
      end
    end

    context "not user's user_email" do
      it "does not enqueue a job and sets the flash" do
        log_in(FactoryBot.create(:user_confirmed))
        post "#{base_url}/#{user_email.id}/make_primary"
        user_email.reload
        expect(user_email.primary?).to be_falsey
        expect(flash[:error]).to match(/signed in with primary email/)
      end
    end

    context "no user, no email_id" do
      it "does not enqueue a job and sets the flash (and does not break)" do
        post "#{base_url}/#{user_email.id}/make_primary"
        user_email.reload
        expect(user_email.primary?).to be_falsey
        expect(flash[:error]).to match(/signed in with primary email/)
      end
    end
  end
end
