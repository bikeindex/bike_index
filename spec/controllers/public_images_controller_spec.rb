require 'spec_helper'

describe PublicImagesController do
  describe 'create' do
    context 'bike' do
      let(:ownership) { FactoryBot.create(:ownership) }
      let(:bike) { ownership.bike }
      let(:user) { ownership.creator }
      context 'valid owner' do
        it 'creates an image' do
          set_current_user(user)
          post :create, bike_id: bike.id, public_image: { name: 'cool name' }, format: :js
          bike.reload
          expect(bike.public_images.first.name).to eq 'cool name'
          expect(AfterBikeSaveWorker).to have_enqueued_sidekiq_job(bike.id)
        end
      end
      context 'no user' do
        it 'does not create an image' do
          expect do
            post :create, bike_id: bike.id, public_image: { name: 'cool name' }, format: :js
            expect(response.code).to eq('401')
          end.to change(PublicImage, :count).by 0
        end
      end
    end
    context 'blog' do
      let(:blog) { FactoryBot.create(:blog) }
      context 'admin authorized' do
        it 'creates an image' do
          user = FactoryBot.create(:content_admin)
          set_current_user(user)
          post :create, blog_id: blog.id, public_image: { name: 'cool name' }, format: :js
          blog.reload
          expect(blog.public_images.first.name).to eq 'cool name'
        end
      end
      context 'not admin' do
        it 'does not create an image' do
          set_current_user(FactoryBot.create(:user_confirmed))
          expect do
            post :create, blog_id: blog.id, public_image: { name: 'cool name' }, format: :js
            expect(response.code).to eq('401')
          end.to change(PublicImage, :count).by 0
        end
      end
    end
    context 'organization' do
      let(:organization) { FactoryBot.create(:organization) }
      context 'admin authorized' do
        include_context :logged_in_as_super_admin
        it 'creates an image' do
          post :create, organization_id: organization.to_param, public_image: { name: 'cool name' }, format: :js
          organization.reload
          expect(organization.public_images.first.name).to eq 'cool name'
        end
      end
      context 'not admin' do
        include_context :logged_in_as_user
        it 'does not create an image' do
          expect do
            post :create, organization_id: organization.to_param, public_image: { name: 'cool name' }, format: :js
            expect(response.code).to eq('401')
          end.to change(PublicImage, :count).by 0
        end
      end
    end
    context 'mail_snippet' do
      let(:mail_snippet) { FactoryBot.create(:mail_snippet) }
      context 'admin authorized' do
        include_context :logged_in_as_super_admin
        it 'creates an image' do
          post :create, mail_snippet_id: mail_snippet.to_param, public_image: { name: 'cool name' }, format: :js
          mail_snippet.reload
          expect(mail_snippet.public_images.first.name).to eq 'cool name'
        end
      end
      context 'not signed in' do
        it 'does not create an image' do
          expect do
            post :create, organization_id: mail_snippet.to_param, public_image: { name: 'cool name' }, format: :js
            expect(response.code).to eq('401')
          end.to change(PublicImage, :count).by 0
        end
      end
    end
  end
  describe 'destroy' do
    context 'with owner' do
      it 'allows the destroy of public_image' do
        user = FactoryBot.create(:user_confirmed)
        bike = FactoryBot.create(:bike)
        FactoryBot.create(:ownership, bike: bike, creator: user, owner_email: user.email)
        public_image = FactoryBot.create(:public_image, imageable: bike)
        expect(bike.reload.owner).to eq(user)
        set_current_user(user)
        expect do
          delete :destroy, id: public_image.id
        end.to change(PublicImage, :count).by(-1)
      end
      context 'non owner' do
        it 'rejects the destroy' do
          ownership = FactoryBot.create(:ownership)
          bike = ownership.bike
          non_owner = FactoryBot.create(:user_confirmed, name: 'Non Owner')
          public_image = FactoryBot.create(:public_image, imageable: bike)
          set_current_user(non_owner)
          expect do
            delete :destroy, id: public_image.id
          end.not_to change(PublicImage, :count)
        end
      end
      context 'owner and hidden bike' do
        it 'allows the destroy' do
          user = FactoryBot.create(:user_confirmed)
          bike = FactoryBot.create(:bike, hidden: true)
          FactoryBot.create(:ownership, bike: bike, creator: user, owner_email: user.email)
          public_image = FactoryBot.create(:public_image, imageable: bike)
          expect(bike.reload.owner).to eq(user)
          set_current_user(user)
          expect do
            delete :destroy, id: public_image.id, page: 'redirect_page'
          end.to change(PublicImage, :count).by(-1)
          expect(response).to redirect_to(edit_bike_path(bike, page: 'redirect_page'))
        end
      end
    end
    context 'with owner' do
      it 'allows a the owner of a public_image to destroy the public_image' do
        user = FactoryBot.create(:user_confirmed)
        bike = FactoryBot.create(:bike)
        FactoryBot.create(:ownership, bike: bike, creator: user, owner_email: user.email)
        public_image = FactoryBot.create(:public_image, imageable: bike)
        expect(bike.reload.owner).to eq(user)
        set_current_user(user)
        expect do
          delete :destroy, id: public_image.id, page: 'redirect_page'
        end.to change(PublicImage, :count).by(-1)
        expect(response).to redirect_to(edit_bike_path(bike, page: 'redirect_page'))
      end
    end
  end

  describe 'show' do
    it 'renders' do
      image = FactoryBot.create(:public_image)
      get :show, id: image.id
      expect(response.code).to eq('200')
      expect(response).to render_template('show')
      expect(flash).to_not be_present
    end
  end

  describe 'edit' do
    it 'renders' do
      ownership = FactoryBot.create(:ownership)
      user = ownership.owner
      set_current_user(user)
      image = FactoryBot.create(:public_image, imageable: ownership.bike)
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
          user = FactoryBot.create(:user_confirmed)
          bike = FactoryBot.create(:bike)
          FactoryBot.create(:ownership, bike: bike, creator: user, owner_email: user.email)
          public_image = FactoryBot.create(:public_image, imageable: bike)
          expect(bike.reload.owner).to eq(user)
          set_current_user(user)
          put :update, id: public_image.id, public_image: { name: 'Food' }
          expect(response).to redirect_to(edit_bike_url(bike))
          expect(public_image.reload.name).to eq('Food')
          # ensure enqueueing after this
        end
      end
      context 'not owner' do
        it 'does not update' do
          user = FactoryBot.create(:user_confirmed)
          bike = FactoryBot.create(:bike)
          FactoryBot.create(:ownership, bike: bike)
          public_image = FactoryBot.create(:public_image, imageable: bike, name: 'party')
          set_current_user(user)
          put :update, id: public_image.id, public_image: { name: 'Food' }
          expect(public_image.reload.name).to eq('party')
        end
      end
    end
  end

  describe 'is_private' do
    let(:user) { FactoryBot.create(:user_confirmed) }
    let(:bike) { FactoryBot.create(:bike) }
    context 'with owner' do
      context 'is_private true' do
        it 'marks image private' do
          FactoryBot.create(:ownership, bike: bike, creator: user, owner_email: user.email)
          public_image = FactoryBot.create(:public_image, imageable: bike)
          expect(bike.reload.owner).to eq(user)
          set_current_user(user)
          post :is_private, id: public_image.id, is_private: 'true'
          public_image.reload
          expect(public_image.is_private).to be_truthy
          expect(AfterBikeSaveWorker).to have_enqueued_sidekiq_job(bike.id)
        end
      end
      context 'is_private false' do
        it 'marks bike not private' do
          FactoryBot.create(:ownership, bike: bike, creator: user, owner_email: user.email)
          public_image = FactoryBot.create(:public_image, imageable: bike, is_private: true)
          expect(bike.reload.owner).to eq(user)
          set_current_user(user)
          post :is_private, id: public_image.id, is_private: false
          public_image.reload
          expect(public_image.is_private).to be_falsey
          expect(AfterBikeSaveWorker).to have_enqueued_sidekiq_job(bike.id)
        end
      end
    end
    context 'non owner' do
      it 'does not update' do
        FactoryBot.create(:ownership, bike: bike)
        public_image = FactoryBot.create(:public_image, imageable: bike, name: 'party')
        set_current_user(user)
        post :is_private, id: public_image.id, is_private: 'true'
        expect(public_image.is_private).to be_falsey
      end
    end
  end

  describe 'order' do
    let(:bike) { FactoryBot.create(:bike) }
    let(:ownership) { FactoryBot.create(:ownership, bike: bike) }
    let(:user) { ownership.creator }
    let(:other_ownership) { FactoryBot.create(:ownership) }
    let(:public_image_1) { FactoryBot.create(:public_image, imageable: bike) }
    let(:public_image_2) { FactoryBot.create(:public_image, imageable: bike, listing_order: 2) }
    let(:public_image_3) { FactoryBot.create(:public_image, imageable: bike, listing_order: 3) }
    let(:public_image_other) { FactoryBot.create(:public_image, imageable: other_ownership.bike, listing_order: 0) }

    it 'updates the listing order' do
      expect([public_image_1, public_image_2, public_image_3, public_image_other]).to be_present
      public_image_other.reload
      expect(public_image_other.listing_order).to eq 0
      expect(public_image_3.listing_order).to eq 3
      expect(public_image_2.listing_order).to eq 2
      expect(public_image_1.listing_order).to be < 2
      list_order = [public_image_3.id, public_image_1.id, public_image_other.id, public_image_2.id]
      set_current_user(user)
      post :order, list_of_photos: list_order.map(&:to_s)
      public_image_1.reload
      public_image_2.reload
      public_image_3.reload
      public_image_other.reload
      expect(public_image_3.listing_order).to eq 1
      expect(public_image_2.listing_order).to eq 4
      expect(public_image_1.listing_order).to eq 2
      expect(public_image_other.listing_order).to eq 0
      expect(AfterBikeSaveWorker).to have_enqueued_sidekiq_job(bike.id)
    end
  end
end
