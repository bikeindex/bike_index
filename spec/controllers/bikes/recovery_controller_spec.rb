require 'spec_helper'

describe Bikes::RecoveryController, type: :controller do
  let(:bike) { FactoryGirl.create(:stolen_bike) }
  let(:stolen_record) { bike.current_stolen_record }
  before { stolen_record.find_or_create_recovery_link_token }

  context 'nonmatching recovery token' do
    describe 'edit' do
      it 'renders' do
        get :edit, bike_id: bike.id, token: 'XXXXXXXX'
        expect(response).to redirect_to bike_url(bike)
        expect(flash).to be_present
      end
    end
  end
  context 'matching recovery token' do
    describe 'edit' do
      it 'renders' do
        get :edit, bike_id: bike.id, token: stolen_record.find_or_create_recovery_link_token
        expect(response).to be_success
        expect(response).to render_template(:edit)
        expect(assigns(:stolen_record)).to eq stolen_record
      end
    end
  end
end
