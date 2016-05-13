require 'spec_helper'

describe PublicImagesController do
  describe 'destroy' do
    context 'legacy' do
      context 'with owner' do
        it 'allows the destroy of publicImage' do
          user = FactoryGirl.create(:user)
          bike = FactoryGirl.create(:bike)
          FactoryGirl.create(:ownership, bike: bike, creator: user, owner_email: user.email)
          publicImage = FactoryGirl.create(:publicImage, imageable: bike)
          expect(bike.reload.owner).to eq(user)
          set_current_user(user)
          expect do
            delete :destroy, id: publicImage.id
          end.to change(PublicImage, :count).by(-1)
        end
      end
      context 'non owner' do
        it 'rejects the destroy' do
          ownership = FactoryGirl.create(:ownership)
          bike = ownership.bike
          non_owner = FactoryGirl.create(:user, name: 'Non Owner')
          publicImage = FactoryGirl.create(:publicImage, imageable: bike)
          set_current_user(non_owner)
          expect do
            delete :destroy, id: publicImage.id
          end.not_to change(PublicImage, :count)
        end
      end
      context 'owner and hidden bike' do
        it 'allows the destroy' do
          user = FactoryGirl.create(:user)
          bike = FactoryGirl.create(:bike, hidden: true)
          FactoryGirl.create(:ownership, bike: bike, creator: user, owner_email: user.email)
          publicImage = FactoryGirl.create(:publicImage, imageable: bike)
          expect(bike.reload.owner).to eq(user)
          set_current_user(user)
          expect do
            delete :destroy, id: publicImage.id, page: 'redirect_page'
          end.to change(PublicImage, :count).by(-1)
          expect(response).to redirect_to(edit_bike_path(bike, page: 'redirect_page'))
        end
      end
    end
    context 'revised' do
      context 'with owner' do
        it 'allows a the owner of a publicImage to destroy the publicImage' do
          user = FactoryGirl.create(:user)
          bike = FactoryGirl.create(:bike)
          FactoryGirl.create(:ownership, bike: bike, creator: user, owner_email: user.email)
          publicImage = FactoryGirl.create(:publicImage, imageable: bike)
          expect(bike.reload.owner).to eq(user)
          set_current_user(user)
          expect do
            delete :destroy, id: publicImage.id, page: 'redirect_page'
          end.to change(PublicImage, :count).by(-1)
          expect(response).to redirect_to(edit_bike_path(bike, page: 'redirect_page'))
        end
      end
    end
  end

  describe 'show' do
    it 'renders' do
      image = FactoryGirl.create(:publicImage)
      get :show, id: image.id
      expect(response.code).to eq('200')
      expect(response).to render_template('show')
      expect(flash).to_not be_present
    end
  end

  describe 'edit' do
    it 'renders' do
      ownership = FactoryGirl.create(:ownership)
      user = ownership.owner
      set_current_user(user)
      image = FactoryGirl.create(:publicImage, imageable: ownership.bike)
      get :edit, id: image.id
      expect(response.code).to eq('200')
      expect(response).to render_template('edit')
      expect(flash).to_not be_present
    end
  end

  describe 'update' do
    context 'normal update' do
      context 'with owner' do
        it 'updates things and go back to editing the bike' do
          user = FactoryGirl.create(:user)
          bike = FactoryGirl.create(:bike)
          FactoryGirl.create(:ownership, bike: bike, creator: user, owner_email: user.email)
          publicImage = FactoryGirl.create(:publicImage, imageable: bike)
          expect(bike.reload.owner).to eq(user)
          set_current_user(user)
          put :update, id: publicImage.id, publicImage: { name: 'Food' }
          expect(response).to redirect_to(edit_bike_url(bike))
          expect(publicImage.reload.name).to eq('Food')
        end
      end
      context 'not owner' do
        it 'does not update' do
          user = FactoryGirl.create(:user)
          bike = FactoryGirl.create(:bike)
          FactoryGirl.create(:ownership, bike: bike)
          publicImage = FactoryGirl.create(:publicImage, imageable: bike, name: 'party')
          set_current_user(user)
          put :update, id: publicImage.id, publicImage: { name: 'Food' }
          expect(publicImage.reload.name).to eq('party')
        end
      end
    end
  end

  describe 'is_private' do
    let(:user) { FactoryGirl.create(:user) }
    let(:bike) { FactoryGirl.create(:bike) }
    context 'with owner' do
      context 'is_private true' do
        it 'marks image private' do
          FactoryGirl.create(:ownership, bike: bike, creator: user, owner_email: user.email)
          publicImage = FactoryGirl.create(:publicImage, imageable: bike)
          expect(bike.reload.owner).to eq(user)
          set_current_user(user)
          post :is_private, id: publicImage.id, is_private: 'true'
          publicImage.reload
          expect(publicImage.is_private).to be_truthy
        end
      end
      context 'is_private false' do
        it 'marks bike not private' do
          FactoryGirl.create(:ownership, bike: bike, creator: user, owner_email: user.email)
          publicImage = FactoryGirl.create(:publicImage, imageable: bike, is_private: true)
          expect(bike.reload.owner).to eq(user)
          set_current_user(user)
          post :is_private, id: publicImage.id, is_private: false
          publicImage.reload
          expect(publicImage.is_private).to be_falsey
        end
      end
    end
    context 'non owner' do
      it 'does not update' do
        FactoryGirl.create(:ownership, bike: bike)
        publicImage = FactoryGirl.create(:publicImage, imageable: bike, name: 'party')
        set_current_user(user)
        post :is_private, id: publicImage.id, is_private: 'true'
        expect(publicImage.is_private).to be_falsey
      end
    end
  end

  describe 'order' do
    let(:bike) { FactoryGirl.create(:bike) }
    let(:ownership) { FactoryGirl.create(:ownership, bike: bike) }
    let(:user) { ownership.creator }
    let(:other_ownership) { FactoryGirl.create(:ownership) }
    let(:publicImage_1) { FactoryGirl.create(:publicImage, imageable: bike) }
    let(:publicImage_2) { FactoryGirl.create(:publicImage, imageable: bike, listing_order: 2) }
    let(:publicImage_3) { FactoryGirl.create(:publicImage, imageable: bike, listing_order: 3) }
    let(:publicImage_other) { FactoryGirl.create(:publicImage, imageable: other_ownership.bike, listing_order: 0) }

    it 'updates the listing order' do
      expect([publicImage_1, publicImage_2, publicImage_3, publicImage_other]).to be_present
      publicImage_other.reload
      expect(publicImage_other.listing_order).to eq 0
      expect(publicImage_3.listing_order).to eq 3
      expect(publicImage_2.listing_order).to eq 2
      expect(publicImage_1.listing_order).to eq 1
      list_order = [publicImage_3.id, publicImage_1.id, publicImage_other.id, publicImage_2.id]
      set_current_user(user)
      post :order, list_of_photos: list_order.map(&:to_s)
      publicImage_1.reload
      publicImage_2.reload
      publicImage_3.reload
      publicImage_other.reload
      expect(publicImage_3.listing_order).to eq 1
      expect(publicImage_2.listing_order).to eq 4
      expect(publicImage_1.listing_order).to eq 2
      expect(publicImage_other.listing_order).to eq 0
    end
  end
end
