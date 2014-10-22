require 'spec_helper'

describe PublicImagesController do
  describe :destroy do
    it "allows a the owner of a public_image to destroy the public_image" do
      user = FactoryGirl.create(:user)
      bike = FactoryGirl.create(:bike)
      o = FactoryGirl.create(:ownership, bike: bike, creator: user, owner_email: user.email)
      public_image = FactoryGirl.create(:public_image, imageable: bike)
      bike.reload.owner.should eq(user)
      set_current_user(user)
      set_current_user(user)
      lambda do
        delete :destroy, id: public_image.id
      end.should change(PublicImage, :count).by(-1)
    end
    
    it "ensures that current user owns image before allowing destroy" do
      ownership = FactoryGirl.create(:ownership)
      bike = ownership.bike
      non_owner = FactoryGirl.create(:user, name: "Non Owner")
      public_image = FactoryGirl.create(:public_image, imageable: bike)
      set_current_user(non_owner)
      lambda do
        delete :destroy, id: public_image.id
      end.should_not change(PublicImage, :count)
    end
  end

  describe :show do 
    before do 
      image = FactoryGirl.create(:public_image)
      get :show, id: image.id
    end
    it { should respond_with(:success) }
    it { should render_template(:show) }
  end


  describe :edit do 
    before do
      image = FactoryGirl.create(:public_image)
      controller.should_receive(:find_image_if_owned).and_return(image)
      get :edit, id: image.id
    end
    it { should respond_with(:success) }
    it { should render_template(:edit) }
  end

  describe :update do 
    it "updates things and go back to editing the bike" do 
      user = FactoryGirl.create(:user)
      bike = FactoryGirl.create(:bike)
      o = FactoryGirl.create(:ownership, bike: bike, creator: user, owner_email: user.email)
      public_image = FactoryGirl.create(:public_image, imageable: bike)
      bike.reload.owner.should eq(user)
      set_current_user(user)
      put :update, {id: public_image.id, public_image: {name: "Food"}}
      response.should redirect_to(edit_bike_url(o.bike))
      public_image.reload.name.should eq("Food")
    end
  end


  # describe :order do 
  #   before :each do 
  #     @public_image2.listing_order = 2
  #     @public_image3 = FactoryGirl.create(:public_image, imageable: @bike)
  #     @public_image3.listing_order = 3
  #   end

  #   it "Should receive a public_image and new_listing_order, and update the correct photo's order should be updated" do  
  #     pp @public_image1
  #     pp @public_image2
  #     pp @public_image3
  #     post :order, public_image: @public_image3.id, new_listing_order: "1"
  #     @public_image3.listing_order.should == 0
  #   end
  # end

end
