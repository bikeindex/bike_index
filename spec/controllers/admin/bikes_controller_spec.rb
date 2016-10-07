require 'spec_helper'

describe Admin::BikesController do
  let(:user) { FactoryGirl.create(:admin) }
  before do
    set_current_user(user)
  end

  describe 'index' do
    it 'renders' do
      get :index
      expect(response.code).to eq('200')
      expect(response).to render_template('index')
      expect(flash).to_not be_present
      expect(assigns(:page_id)).to eq 'admin_bikes_index'
    end
  end

  describe 'duplicates' do
    it 'renders' do
      get :duplicates
      expect(response.code).to eq('200')
      expect(response).to render_template('duplicates')
      expect(flash).to_not be_present
    end
  end

  describe 'edit' do
    it 'renders' do
      bike = FactoryGirl.create(:bike)
      get :edit, id: bike.id
      expect(response.code).to eq('200')
      expect(response).to render_template('edit')
      expect(flash).to_not be_present
    end
  end

  describe 'destroy' do
    it 'destroys the bike' do
      bike = FactoryGirl.create(:bike)
      expect do
        delete :destroy, id: bike.id
      end.to change(Bike, :count).by(-1)
      expect(response).to redirect_to(:admin_bikes)
      expect(flash[:success]).to match(/deleted/i)
      expect(AfterBikeSaveWorker).to have_enqueued_job(bike.id)
    end
  end

  describe 'update' do
    context 'success' do
      let(:organization) { FactoryGirl.create(:organization) }
      it 'updates the bike and calls update_ownership and serial_normalizer' do
        expect_any_instance_of(BikeUpdator).to receive(:update_ownership)
        expect_any_instance_of(SerialNormalizer).to receive(:save_segments)
        bike = FactoryGirl.create(:stolen_bike)
        stolen_record = bike.find_current_stolen_record
        expect(stolen_record).to be_present
        expect(stolen_record.is_a?(StolenRecord)).to be_truthy
        bike_attributes = {
          serial_number: 'new thing and stuff',
          bike_organization_ids: ['', organization.id.to_s],
          stolen_records_attributes: {
            "0"=> {
              street: 'Cortland and Ashland',
              city: 'Chicago'
            }
          }
        }
        put :update, id: bike.id, bike: bike_attributes
        expect(flash[:success]).to be_present
        expect(response).to redirect_to(:edit_admin_bike)
        bike.reload
        expect(bike.serial_number).to eq bike_attributes[:serial_number]
        expect(bike.find_current_stolen_record.id).to eq stolen_record.id
        stolen_record.reload
        expect(stolen_record.street).to eq 'Cortland and Ashland'
        expect(stolen_record.city).to eq 'Chicago'
        expect(bike.bike_organization_ids).to eq([organization.id])
      end
    end

    context 'fast_attr_update' do
      it 'marks a stolen bike recovered and passes attr update through' do
        bike = FactoryGirl.create(:stolen_bike)
        stolen_record = bike.current_stolen_record
        bike.reload
        expect(bike.stolen).to be_truthy
        opts = {
          id: bike.id,
          mark_recovered_reason: 'I recovered it',
          mark_recovered_we_helped: true,
          can_share_recovery: 1,
          fast_attr_update: true,
          bike: { stolen: 0 }
        }
        put :update, opts
        bike.reload
        stolen_record.reload
        expect(bike.stolen).to be_falsey
        expect(bike.current_stolen_record).not_to be_present
        expect(stolen_record.reload.date_recovered).to be_within(1.second).of Time.now
        expect(stolen_record.index_helped_recovery).to be_truthy
        expect(stolen_record.can_share_recovery).to be_truthy
        expect(assigns(:fast_attr_update)).to be_truthy
        bike.reload
        expect(bike.stolen).to be_falsey
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

  describe 'ignore_duplicate' do
    before do
      request.env['HTTP_REFERER'] = 'http://localhost:3000/admin/bikes/missing_manufacturers'
    end
    context 'marked ignore' do
      it 'duplicates are ignore' do
        duplicate_bike_group = DuplicateBikeGroup.create
        expect(duplicate_bike_group.ignore).to be_falsey
        put :ignore_duplicate_toggle, id: duplicate_bike_group.id
        duplicate_bike_group.reload

        expect(duplicate_bike_group.ignore).to be_truthy
        expect(response).to redirect_to 'http://localhost:3000/admin/bikes/missing_manufacturers'
      end
    end

    context 'duplicate group unignore' do
      it 'marks a duplicate group unignore' do
        duplicate_bike_group = DuplicateBikeGroup.create(ignore: true)
        expect(duplicate_bike_group.ignore).to be_truthy
        put :ignore_duplicate_toggle, id: duplicate_bike_group.id
        duplicate_bike_group.reload

        expect(duplicate_bike_group.ignore).to be_falsey
        expect(response).to redirect_to 'http://localhost:3000/admin/bikes/missing_manufacturers'
      end
    end
  end

  describe 'update_manufacturers' do
    before do
      request.env['HTTP_REFERER'] = 'http://localhost:3000/admin/bikes/missing_manufacturers'
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
