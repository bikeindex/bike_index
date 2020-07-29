require "rails_helper"

RSpec.describe Organized::OperateLinesController, type: :request do
  include_context :request_spec_logged_in_as_organization_member
  let(:base_url) { "/o/#{current_organization.to_param}/operate_lines" }
  let(:appointment) { FactoryBot.create(:appointment, status: status, location: location, organization: current_organization) }
  let(:location) { FactoryBot.create(:location, :with_virtual_line_on) }
  let(:current_organization) { location.organization }

  describe "index" do
    it "redirects to show" do
      expect(current_organization.appointment_functionality_enabled?).to be_truthy
      # there in only one location
      expect(current_organization.locations.pluck(:id)).to eq([location.id])
      get base_url
      expect(assigns(:current_location)&.id).to eq location.id
      expect(response).to redirect_to organization_operate_line_path(location.to_param, organization_id: current_organization.to_param)
      expect(flash).to be_blank
    end
    context "with two locations" do
      let!(:location2) { FactoryBot.create(:location, :with_virtual_line_on, organization: current_organization) }
      it "renders" do
        expect(location2.virtual_line_on?).to be_truthy
        # there are two locations
        expect(current_organization.locations.pluck(:id)).to match_array([location.id, location2.id])
        get base_url
        expect(assigns(:current_location)).to be_blank
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
        expect(flash).to be_blank

        get "#{base_url}/#{location2.id}"
        expect(assigns(:current_location)&.id).to eq location2.id
        expect(response.status).to eq(200)
        expect(response).to render_template(:show)
        expect(flash).to be_blank
      end
    end
  end

  describe "show" do
    it "renders" do
      get "#{base_url}/#{location.to_param}"
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
      expect(flash).to be_blank
    end
  end

  describe "update" do
    let!(:appointment2) { FactoryBot.create(:appointment, status: "on_deck", organization: current_organization, location: location) }
    it "updates multiple appointments" do
      expect {
        put "#{base_url}/#{location.to_param}", params: {
          status: "being_helped",
          organization: current_organization.to_param,
          ids: {
            appointment.id.to_s => appointment.id.to_s,
            appointment2.id.to_s => appointment2.id.to_s
          }
        }
      }.to change(AppointmentUpdate, :count).by 2
      expect(response).to redirect_to organization_operate_line_path(location.to_param, organization_id: current_organization.to_param)
      expect(flash[:success]).to be_present
      appointment.reload
      appointment2.reload

      expect(appointment.status).to eq "being_helped"
      expect(appointment2.status).to eq "being_helped"

      expect(appointment.appointment_updates.count).to eq 1
      expect(appointment.appointment_updates.last.organization_member?).to be_truthy
      expect(appointment2.appointment_updates.last.user_id).to eq current_user.id
      # updating with no ids doesn't break
      expect {
        put "#{base_url}/#{location.to_param}", params: {
          status: "being_helped",
          organization: current_organization.to_param
        }
      }.to_not change(AppointmentUpdate, :count)
      expect(response).to redirect_to organization_operate_line_path(location.to_param, organization_id: current_organization.to_param)
      expect(flash[:notice]).to be_present
    end
  end
end
