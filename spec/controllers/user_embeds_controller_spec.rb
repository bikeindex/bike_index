require 'spec_helper'

describe UserEmbedsController do
  describe 'show' do
    it 'renders the page if username is found' do
      user = FactoryGirl.create(:user, show_bikes: true)
      ownership = FactoryGirl.create(:ownership, user_id: user.id, current: true)
      get :show, id: user.username
      expect(response.code).to eq('200')
      expect(assigns(:bikes).first).to eq(ownership.bike)
      expect(assigns(:bikes).count).to eq(1)
      expect(response.headers['X-Frame-Options']).not_to be_present
    end

    it "renders the most recent bikes with images if it doesn't find the user" do
      public_image = FactoryGirl.create(:public_image)
      bike = public_image.imageable
      allow_any_instance_of(Bike).to receive(:public_images) { [public_image] }
      bike.save && bike.reload
      expect(bike.thumb_path).to be_present
      get :show, id: 'NOT A USER'
      expect(response.code).to eq('200')
      expect(assigns(:bikes).count).to eq(1)
      expect(response.headers['X-Frame-Options']).not_to be_present
    end
  end
end
