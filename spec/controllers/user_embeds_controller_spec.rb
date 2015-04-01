require 'spec_helper'

describe UserEmbedsController do

  describe :show do 
    it "renders the page if username is found" do
      user = FactoryGirl.create(:user, show_bikes: true)
      ownership = FactoryGirl.create(:ownership, user_id: user.id, current: true)
      get :show, id: user.username
      response.code.should eq('200')
      assigns(:bikes).first.should eq(ownership.bike)
      assigns(:bikes).count.should eq(1)
      response.headers['X-Frame-Options'].should_not be_present
    end

    it "renders the most recent bikes with images if it doesn't find the user" do
      FactoryGirl.create(:bike)
      bike = FactoryGirl.create(:bike, thumb_path: "blah")
      get :show, id: "NOT A USER"
      response.code.should eq('200')
      assigns(:bikes).count.should eq(1)
      response.headers['X-Frame-Options'].should_not be_present
    end
  end

end
