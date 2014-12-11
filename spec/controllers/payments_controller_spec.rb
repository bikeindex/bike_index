require 'spec_helper'

describe PaymentsController do

  describe :new do 
    describe :with_user do 
      before do 
        user = FactoryGirl.create(:user)
        set_current_user(user)
        get :new
      end
      it { should respond_with(:success) }
      it { should render_template(:new) }
    end
    describe :without_user do 
      before do 
        get :new
      end
      it { should respond_with(:success) }
      it { should render_template(:new) }
    end
  end

  describe :create do 
    it "should make a onetime payment with current user" do 
      token = Stripe::Token.create(
        :card => {
          :number => "4242424242424242",
          :exp_month => 12,
          :exp_year => 2015,
          :cvc => "314"
        },
      )
      user = FactoryGirl.create(:user)
      set_current_user(user)
      opts = { stripe_token: token.id,
        stripe_email: user.email,
        stripe_amount: 4000
      }
      lambda {
        post :create, opts
      }.should change(Payment, :count).by(1)
      payment = Payment.last
      payment.user_id.should eq(user.id)
      user.reload.stripe_id.should be_present
      payment.stripe_id.should be_present
      payment.first_payment_date.should be_present
      payment.last_payment_date.should_not be_present
    end

    it "should make a onetime payment with email for signed up user" do 
      token = Stripe::Token.create(
        :card => {
          :number => "4242424242424242",
          :exp_month => 12,
          :exp_year => 2015,
          :cvc => "314"
        },
      )
      user = FactoryGirl.create(:user)
      opts = { stripe_token: token.id,
        stripe_amount: 4000,
        stripe_email: user.email
      }
      lambda {
        post :create, opts
      }.should change(Payment, :count).by(1)
      payment = Payment.last
      payment.user_id.should eq(user.id)
      user.reload.stripe_id.should be_present
      payment.stripe_id.should be_present
      payment.first_payment_date.should be_present
      payment.last_payment_date.should_not be_present
    end

    it "should make a onetime payment with no user, but associate with stripe" do 
      token = Stripe::Token.create(
        :card => {
          :number => "4242424242424242",
          :exp_month => 12,
          :exp_year => 2015,
          :cvc => "314"
        },
      )
      opts = { stripe_token: token.id,
        stripe_amount: 4000,
        stripe_email: "test_user@rspec.com"
      }
      lambda {
        post :create, opts
      }.should change(Payment, :count).by(1)
      payment = Payment.last
      payment.email.should eq("test_user@rspec.com")
      # assigns(:customer_id).should eq('cus_5IwBxTiMCDIqYM')
      payment.stripe_id.should be_present
      payment.first_payment_date.should be_present
      payment.last_payment_date.should_not be_present
    end

    it "should sign up for a plan" do 
      token = Stripe::Token.create(
        :card => {
          :number => "4242424242424242",
          :exp_month => 12,
          :exp_year => 2015,
          :cvc => "314"
        },
      )
      user = FactoryGirl.create(:user)
      set_current_user(user)
      opts = { stripe_token: token.id,
        stripe_email: user.email,
        stripe_amount: 4000,
        stripe_subscription: 1,
        stripe_plan: "01",
      }
      lambda {
        post :create, opts
      }.should change(Payment, :count).by(1)
      payment = Payment.last
      payment.is_recurring.should be_true
      payment.user_id.should eq(user.id)
      user.reload.stripe_id.should be_present
      payment.stripe_id.should be_present
      payment.first_payment_date.should be_present
      payment.last_payment_date.should_not be_present
    end
  end

end
