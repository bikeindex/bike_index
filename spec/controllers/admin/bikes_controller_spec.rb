require 'spec_helper'

describe Admin::BikesController do
  let(:user) { FactoryGirl.create(:admin) }
  before do
    set_current_user(user)
  end

  describe :index do
    it 'renders' do
      get :index
      expect(response.code).to eq('200')
      expect(response).to render_template('index')
      expect(flash).to_not be_present
    end
  end

  describe :duplicates do
    it 'renders' do
      get :duplicates
      expect(response.code).to eq('200')
      expect(response).to render_template('duplicates')
      expect(flash).to_not be_present
    end
  end

  describe :edit do
    it 'renders' do
      bike = FactoryGirl.create(:bike)
      get :edit, id: bike.id
      expect(response.code).to eq('200')
      expect(response).to render_template('edit')
      expect(flash).to_not be_present
    end
  end

  describe :destroy do
    it 'destroys the bike' do
      bike = FactoryGirl.create(:bike)
      # We execute the after bike save worker inline because we're destroying the bike
      expect_any_instance_of(AfterBikeSaveWorker).to receive(:perform) { bike.id }
      expect do
        delete :destroy, id: bike.id
      end.to change(Bike, :count).by(-1)
      expect(response).to redirect_to(:admin_bikes)
      expect(flash[:notice]).to match(/deleted/i)
    end
  end

  describe :update do
    context 'success' do
      it 'updates the bike and calls update_ownership and serial_normalizer' do
        expect_any_instance_of(BikeUpdator).to receive(:update_ownership)
        expect_any_instance_of(SerialNormalizer).to receive(:save_segments)
        bike = FactoryGirl.create(:bike)
        put :update, id: bike.id
        expect(response).to redirect_to(:edit_admin_bike)
        expect(flash).to be_present
      end
    end

    context 'fast_attr_update' do
      it 'marks a stolen bike recovered and passes attr update through' do
        bike = FactoryGirl.create(:stolen_bike)
        bike.reload
        expect(bike.stolen).to be_true
        opts = {
          id: bike.id,
          mark_recovered_reason: "I recovered it", 
          index_helped_recovery: true,
          can_share_recovery: 1,
          fast_attr_update: true,
          bike: { stolen: 0 }
        }
        expect do
          put :update, opts
        end.to change(RecoveryUpdateWorker.jobs, :size).by(1)
        expect(assigns(:fast_attr_update)).to be_true
        bike.reload
        expect(bike.stolen).to be_false
      end
    end

    context 'valid return_to url' do
      it 'redirects' do
        bike = FactoryGirl.create(:bike, serial_number: 'og serial')
        session[:return_to] = '/about'
        opts = {
          id: bike.id,
          bike: { serial_number: 'ssssssssss' }
        }
        put :update, opts
        bike.reload
        expect(bike.serial_number).to eq('ssssssssss')
        expect(response).to redirect_to '/about'
        expect(session[:return_to]).to be_nil
      end
    end
  end

  describe :ignore_duplicate do
    before do
      request.env["HTTP_REFERER"] = 'http://lvh.me:3000/admin/bikes/missing_manufacturers'
    end
    context 'marked ignore' do
      it 'duplicates are ignore' do
        duplicate_bike_group = DuplicateBikeGroup.create
        expect(duplicate_bike_group.ignore).to be_false
        put :ignore_duplicate_toggle, id: duplicate_bike_group.id 
        duplicate_bike_group.reload

        expect(duplicate_bike_group.ignore).to be_true
        expect(response).to redirect_to 'http://lvh.me:3000/admin/bikes/missing_manufacturers'
      end
    end

    context 'duplicate group unignore' do
      it "marks a duplicate group unignore" do
        duplicate_bike_group = DuplicateBikeGroup.create(ignore: true)
        expect(duplicate_bike_group.ignore).to be_true
        put :ignore_duplicate_toggle, id: duplicate_bike_group.id 
        duplicate_bike_group.reload

        expect(duplicate_bike_group.ignore).to be_false
        expect(response).to redirect_to 'http://lvh.me:3000/admin/bikes/missing_manufacturers'
      end
    end
  end

  describe :update_manufacturers do
    before do
      request.env['HTTP_REFERER'] = 'http://lvh.me:3000/admin/bikes/missing_manufacturers'
    end
    it 'updates the products' do
      bike1 = FactoryGirl.create(:bike, manufacturer_other: 'hahaha')
      bike2 = FactoryGirl.create(:bike, manufacturer_other: '69')
      bike3 = FactoryGirl.create(:bike, manufacturer_other: '69')
      manufacturer = FactoryGirl.create(:manufacturer)
      update_params = {
        manufacturer_id: manufacturer.id,
        bikes_selected: { bike1.id => bike1.id, bike2.id => bike2.id }
      }
      post :update_manufacturers, update_params
      [bike1, bike2].each do |bike|
        bike.reload
        expect(bike.manufacturer).to eq manufacturer
        expect(bike.manufacturer_other).to be_nil
      end
      bike3.reload
      expect(bike3.manufacturer_other).to eq '69' # Sanity check
    end
  end
end
