require 'spec_helper'

describe Admin::StolenBikesController do
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

  describe 'update' do
    context 'success' do
      it 'updates the bike and calls update_ownership and serial_normalizer' do
        expect_any_instance_of(BikeUpdator).to receive(:update_ownership)
        expect_any_instance_of(SerialNormalizer).to receive(:save_segments)
        ownership = FactoryGirl.create(:ownership)
        bike = ownership.bike
        put :update, id: bike.id
        expect(response).to redirect_to(:edit_admin_stolen_bike)
        expect(flash).to be_present
      end
    end
  end
end
