require 'spec_helper'

describe PaymentsController do
  let(:user) { FactoryGirl.create(:user) }

  describe :new do
    context 'with user' do
      before do
        set_current_user(user)
      end
      context 'legacy' do
        it 'renders' do
          get :new
          expect(response.code).to eq('200')
          expect(response).to render_template('new')
          expect(response).to render_with_layout('application_updated')
          expect(flash).to_not be_present
        end
      end
      context 'revised' do
        it 'renders' do
          allow(controller).to receive(:revised_layout_enabled?) { true }
          get :new
          expect(response.code).to eq('200')
          expect(response).to render_template('new')
          expect(response).to render_with_layout('application_revised')
          expect(flash).to_not be_present
        end
      end
    end
    context 'without user' do
      context 'legacy' do
        it 'renders' do
          get :new
          expect(response.code).to eq('200')
          expect(response).to render_template('new')
          expect(response).to render_with_layout('application_updated')
          expect(flash).to_not be_present
        end
      end
      context 'revised' do
        it 'renders' do
          allow(controller).to receive(:revised_layout_enabled?) { true }
          get :new
          expect(response.code).to eq('200')
          expect(response).to render_template('new')
          expect(response).to render_with_layout('application_revised')
          expect(flash).to_not be_present
        end
      end
    end
  end

  describe :create do
    let(:token) do
      Stripe::Token.create(
        card: {
          number: '4242424242424242',
          exp_month: 12,
          exp_year: 2025,
          cvc: '314'
        }
      )
    end

    context 'with user' do
      before do
        set_current_user(user)
      end
      it 'makes a onetime payment with current user (and renders with revised_layout if suppose to)' do
        opts = {
          stripe_token: token.id,
          stripe_email: user.email,
          stripe_amount: 4000
        }
        allow(controller).to receive(:revised_layout_enabled?) { true }
        expect do
          post :create, opts
        end.to change(Payment, :count).by(1)
        expect(response).to render_with_layout('application_revised')
        payment = Payment.last
        expect(payment.user_id).to eq(user.id)
        user.reload
        expect(user.stripe_id).to be_present
        expect(payment.stripe_id).to be_present
        expect(payment.first_payment_date).to be_present
        expect(payment.last_payment_date).to_not be_present
      end

      it 'signs up for a plan' do
        opts = {
          stripe_token: token.id,
          stripe_email: user.email,
          stripe_amount: 4000,
          stripe_subscription: 1,
          stripe_plan: '01'
        }
        expect do
          post :create, opts
        end.to change(Payment, :count).by(1)
        payment = Payment.last
        expect(payment.is_recurring).to be_true
        expect(payment.user_id).to eq user.id
        user.reload
        expect(user.stripe_id).to be_present
        expect(payment.stripe_id).to be_present
        expect(payment.first_payment_date).to be_present
        expect(payment.last_payment_date).to_not be_present
      end
    end

    context 'email of signed up user' do
      it 'makes a onetime payment with email for signed up user' do
        opts = {
          stripe_token: token.id,
          stripe_amount: 4000,
          stripe_email: user.email,
          stripe_plan: '',
          stripe_subscription: ''
        }
        expect do
          post :create, opts
        end.to change(Payment, :count).by(1)
        expect(response).to render_with_layout('application_updated')
        payment = Payment.last
        expect(payment.user_id).to eq(user.id)
        user.reload
        expect(user.stripe_id).to be_present
        expect(payment.stripe_id).to be_present
        expect(payment.first_payment_date).to be_present
        expect(payment.last_payment_date).to_not be_present
      end
    end
    context 'no user email on file' do
      it 'makes a onetime payment with no user, but associate with stripe' do
        opts = {
          stripe_token: token.id,
          stripe_amount: 4000,
          stripe_email: 'test_user@test.com'
        }
        expect do
          post :create, opts
        end.to change(Payment, :count).by(1)
        payment = Payment.last
        payment.email.should eq('test_user@test.com')
        expect(payment.stripe_id).to be_present
        expect(payment.first_payment_date).to be_present
        expect(payment.last_payment_date).to_not be_present
      end
    end
  end
end