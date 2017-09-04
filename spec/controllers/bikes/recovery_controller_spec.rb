require 'spec_helper'

describe Bikes::RecoveryController, type: :controller do
  let(:bike) { FactoryGirl.create(:stolen_bike) }
  let(:stolen_record) { bike.current_stolen_record }
  let(:recovery_link_token) { stolen_record.find_or_create_recovery_link_token }

  describe 'edit' do
    context 'nonmatching recovery token' do
      it 'renders' do
        get :edit, bike_id: bike.id, token: 'XXXXXXXX'
        expect(response).to redirect_to bike_url(bike)
        expect(flash[:error]).to be_present
        expect(session[:recovery_link_token]).to be_blank
      end
    end
    context 'matching recovery token' do
      it 'renders' do
        get :edit, bike_id: bike.id, token: recovery_link_token
        expect(response).to redirect_to bike_path(bike)
        expect(session[:recovery_link_token]).to eq recovery_link_token
      end
    end
    context 'already recovered bike' do
      before { stolen_record.add_recovery_information }
      it 'redirects' do
        bike.reload
        expect(bike.stolen).to be_falsey
        get :edit, bike_id: bike.id, token: recovery_link_token
        expect(response).to redirect_to bike_url(bike)
        expect(flash[:info]).to match(/already/)
        expect(session[:recovery_link_token]).to be_blank
      end
    end
  end

  describe 'update' do
    let(:recovery_info) do
      {
        date_recovered: 'Sun Aug 20 2017',
        recovered_description: 'Some sweet description',
        index_helped_recovery: '0',
        can_share_recovery: '1'
      }
    end
    context 'matching recovery token' do
      it 'updates' do
        expect do
          put :update, bike_id: bike.id, token: recovery_link_token,
                       stolen_record: recovery_info
        end.to change(EmailRecoveredFromLinkWorker.jobs, :size).by(1)
        stolen_record.reload
        bike.reload

        expect(bike.stolen).to be_falsey
        expect(stolen_record.recovered?).to be_truthy
        expect(stolen_record.current).to be_falsey
        expect(bike.current_stolen_record).not_to be_present
        expect(stolen_record.index_helped_recovery).to be_falsey
        expect(stolen_record.can_share_recovery).to be_truthy
        expect(stolen_record.recovered_description).to eq recovery_info[:recovered_description]
        expect(stolen_record.reload.date_recovered.to_date).to eq Date.civil(2017, 8, 20)
      end
    end
    context 'non-matching recovery token' do
      it 'does not update' do
        expect do
          put :update, bike_id: bike.id, token: 'XDSFCVVVVVVVVVSD888',
                       stolen_record: recovery_info
        end.to change(EmailRecoveredFromLinkWorker.jobs, :size).by(0)
        stolen_record.reload
        bike.reload

        expect(response).to redirect_to bike_url(bike)
        expect(flash[:error]).to be_present
        expect(bike.stolen).to be_truthy
        expect(stolen_record.recovered?).to be_falsey
        expect(stolen_record.current).to be_truthy
        expect(bike.current_stolen_record).to be_present
      end
    end
  end
end
