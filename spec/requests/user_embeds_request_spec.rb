require "rails_helper"

base_url = "/user_embeds"
RSpec.describe UserEmbedsController, type: :request do
  describe "show" do
    it "renders the page if username is found" do
      user = FactoryBot.create(:user, show_bikes: true)
      ownership = FactoryBot.create(:ownership, user_id: user.id, current: true)
      get "#{base_url}/#{user.username}"
      expect(response.code).to eq("200")
      expect(assigns(:bikes).first).to eq(ownership.bike)
      expect(assigns(:bikes).count).to eq(1)
      expect(response.headers["X-Frame-Options"]).to be_blank
    end

    it "renders the most recent bikes with images if it doesn't find the user" do
      public_image = FactoryBot.create(:public_image)
      bike = public_image.imageable
      bike.save && bike.reload
      expect(bike.thumb_path).to be_present
      get "#{base_url}/NOT-AUSER"
      expect(response.code).to eq("200")
      expect(assigns(:bikes).count).to eq(1)
      expect(response.headers["X-Frame-Options"]).to be_blank
    end
  end
end
