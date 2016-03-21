require 'spec_helper'


describe Membership do
  describe :create do
    before :each do
      @organization = FactoryGirl.create(:organization)
      @user = FactoryGirl.create(:user)
    end
  end
end
