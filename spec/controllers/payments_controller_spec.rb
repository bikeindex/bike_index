require 'spec_helper'

describe PaymentsController do

  describe :new do 
    before do 
      user = FactoryGirl.create(:user)
      set_current_user(user)
      get :new
    end
    it { should respond_with(:success) }
    it { should render_template(:new) }
  end

  describe :create do 
    it "should make a payment" do 
      token = Stripe::Token.create(
        :card => {
          :number => "4242424242424242",
          :exp_month => 12,
          :exp_year => 2015,
          :cvc => "314"
        },
      )
      organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user)
      set_current_user(user)
      opts = { stripe_token: token.id,
        stripe_amount: 4000
      }
      lambda {
        post :create, opts
      }.should change(Payment, :count).by(1)
      payment = Payment.last
      payment.user_id.should eq(user.id)
      payment.stripe_id.should be_present
    end
  end

end
