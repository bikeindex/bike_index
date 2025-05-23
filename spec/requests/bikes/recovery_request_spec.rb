require "rails_helper"

RSpec.describe Bikes::RecoveryController, type: :request do
  let(:base_url) { "/bikes/#{bike.to_param}/recovery" }
  let(:bike) { FactoryBot.create(:stolen_bike) }
  let(:stolen_record) { bike.current_stolen_record }
  let(:recovery_link_token) { stolen_record.find_or_create_recovery_link_token }

  describe "edit" do
    context "nonmatching recovery token" do
      it "redirects" do
        get "#{base_url}/edit?token=XXXXXXXX"
        expect(response).to redirect_to bike_url(bike)
        expect(flash[:error]).to be_present
        expect(session[:recovery_link_token]).to be_blank
      end
    end
    context "matching recovery token" do
      it "renders" do
        get "#{base_url}/edit?token=#{recovery_link_token}"
        expect(response).to redirect_to bike_path(bike)
        expect(session[:recovery_link_token]).to eq recovery_link_token
      end
    end
    context "already recovered bike" do
      before { stolen_record.add_recovery_information }
      it "redirects" do
        bike.reload
        expect(bike.status_stolen?).to be_falsey
        get "#{base_url}/edit?token=#{recovery_link_token}"
        expect(response).to redirect_to bike_url(bike)
        expect(flash[:info]).to match(/already/)
        expect(session[:recovery_link_token]).to be_blank
      end
    end
  end

  describe "update" do
    let(:recovery_info) do
      {
        recovered_at: "2018-07-28T18:57:13.277",
        timezone: "America/Monterrey",
        recovered_description: "Some sweet description",
        index_helped_recovery: "0",
        can_share_recovery: "1"
      }
    end

    context "matching recovery token" do
      it "updates if recovery information is valid" do
        expect {
          put base_url,
            params: {
              bike_id: bike.id,
              token: recovery_link_token,
              stolen_record: recovery_info
            }
        }.to change(Email::RecoveredFromLinkJob.jobs, :size).by(1)
        stolen_record.reload
        bike.reload
        expect(bike.status_stolen?).to be_falsey
        expect(stolen_record.recovered?).to be_truthy
        expect(stolen_record.current).to be_falsey
        expect(bike.current_stolen_record).not_to be_present
        expect(stolen_record.index_helped_recovery).to be_falsey
        expect(stolen_record.can_share_recovery).to be_truthy
        expect(stolen_record.recovered_description).to eq recovery_info[:recovered_description]
        expect(stolen_record.reload.recovered_at.to_i).to be_within(1).of 1532822233
        expect(stolen_record.recovering_user).to be_nil
      end

      context "with user present" do
        include_context :request_spec_logged_in_as_user
        it "updates and assigns recovering_user" do
          expect {
            put base_url, params: {bike_id: bike.id, token: recovery_link_token, stolen_record: recovery_info}
          }.to change(Email::RecoveredFromLinkJob.jobs, :size).by(1)
          stolen_record.reload
          bike.reload

          expect(bike.status_stolen?).to be_falsey
          expect(stolen_record.recovered?).to be_truthy
          expect(stolen_record.current).to be_falsey
          expect(bike.current_stolen_record).not_to be_present
          expect(stolen_record.index_helped_recovery).to be_falsey
          expect(stolen_record.can_share_recovery).to be_truthy
          expect(stolen_record.recovered_description).to eq recovery_info[:recovered_description]
          expect(stolen_record.reload.recovered_at.to_i).to be_within(1).of 1532822233
          expect(stolen_record.recovering_user&.id).to eq current_user.id
        end
      end
    end
    context "non-matching recovery token" do
      it "does not update" do
        expect {
          put base_url, params: {bike_id: bike.id, token: "XDSFCVVVVVVVVVSD888", stolen_record: recovery_info}
        }.to change(Email::RecoveredFromLinkJob.jobs, :size).by(0)
        stolen_record.reload
        bike.reload

        expect(response).to redirect_to bike_url(bike)
        expect(flash[:error]).to be_present
        expect(bike.status_stolen?).to be_truthy
        expect(stolen_record.recovered?).to be_falsey
        expect(stolen_record.current).to be_truthy
        expect(bike.current_stolen_record).to be_present
      end
    end
  end
end
