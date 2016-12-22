require 'spec_helper'

describe PaymentsController do
  let(:user) { FactoryGirl.create(:user) }

  describe 'new' do
    context 'with user' do
      before do
        set_current_user(user)
      end
      it 'renders' do
        get :new
        expect(response.code).to eq('200')
        expect(response).to render_template('new')
        expect(response).to render_with_layout('payments_layout')
        expect(flash).to_not be_present
      end
    end
    context 'without user' do
      it 'renders' do
        get :new
        expect(response.code).to eq('200')
        expect(response).to render_template('new')
        expect(response).to render_with_layout('payments_layout')
        expect(flash).to_not be_present
      end
    end
  end

  describe 'create' do
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
        expect do
          post :create, stripe_token: token.id,
            stripe_email: user.email,
            stripe_amount: 4000
        end.to change(Payment, :count).by(1)
        expect(response).to render_with_layout('payments_layout')
        payment = Payment.last
        expect(payment.user_id).to eq(user.id)
        user.reload
        expect(user.stripe_id).to be_present
        expect(payment.stripe_id).to be_present
        expect(payment.first_payment_date).to be_present
        expect(payment.last_payment_date).to_not be_present
      end

      it 'signs up for a plan' do
        expect do
          post :create, stripe_token: token.id,
            stripe_email: user.email,
            stripe_amount: 4000,
            stripe_subscription: 1,
            stripe_plan: '01'
        end.to change(Payment, :count).by(1)
        payment = Payment.last
        expect(payment.is_recurring).to be_truthy
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
        expect do
          post :create, stripe_token: token.id,
            stripe_amount: 4000,
            stripe_email: user.email,
            stripe_plan: '',
            stripe_subscription: ''
        end.to change(Payment, :count).by(1)
        expect(response).to render_with_layout('payments_layout')
        payment = Payment.last
        expect(payment.user_id).to eq(user.id)
        user.reload
        expect(user.stripe_id).to be_present
        expect(payment.stripe_id).to be_present
        expect(payment.first_payment_date).to be_present
        expect(payment.last_payment_date).to_not be_present
        expect(payment.is_donation).to be_truthy
      end
    end
    context 'no user email on file' do
      it 'makes a onetime payment with no user, but associate with stripe' do
        expect do
          post :create, stripe_token: token.id,
            stripe_amount: 4000,
            stripe_email: 'test_user@test.com',
            is_payment: 1
        end.to change(Payment, :count).by(1)
        payment = Payment.last
        expect(payment.email).to eq('test_user@test.com')
        expect(payment.stripe_id).to be_present
        expect(payment.first_payment_date).to be_present
        expect(payment.last_payment_date).to_not be_present
        expect(payment.is_donation).to be_falsey
      end
    end
  end
end
