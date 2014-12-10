require 'spec_helper'

describe Payment do
  describe :validations do
    it { should belong_to :user }
    it { should validate_presence_of :user_id }
  end


  describe :mark_closed do 
    xit "marks the subscription not current" do 
      user = FactoryGirl.create(:user)
      t = Time.now
      subscription = Subscription.create(stripe_plan_id: '69', user_id: user.id)
      user.reload.is_subscribed.should be_true
      subscription.is_current.should be_true 
      subscription.mark_closed(t)
      subscription.is_current.should be_false
      subscription.end_date.should be > Time.now - 1.seconds
    end 
  end



end
