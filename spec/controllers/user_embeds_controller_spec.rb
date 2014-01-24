require 'spec_helper'

describe UserEmbedsController do

  describe :show do 
    it "should render the page if username is found" do
      user = FactoryGirl.create(:user)
      bike = FactoryGirl.create(:ownership, user: user).bike
      get :show, id: user.username
      response.code.should eq('200')
      assigns(:bikes).first.should eq(bike)
      assigns(:bikes).count.should eq(1)
    end
    it "should render the most recent bikes with images if it doesn't find the user" do
      FactoryGirl.create(:bike)
      bike = FactoryGirl.create(:bike, thumb_path: "blah")
      get :show, id: "NOT A USER"
      response.code.should eq('200')
      assigns(:bikes).count.should eq(1)
    end
  end
end