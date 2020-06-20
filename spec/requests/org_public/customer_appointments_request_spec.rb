require "rails_helper"

RSpec.describe OrgPublic::CustomerAppointmentsController, type: :request do
  let(:base_url) { "/#{current_organization.to_param}/customer_appointments" }
  let(:appointment) { FactoryBot.create(:appointment) }
  let(:location) { appointment.location }
  let(:current_organization) { location.organization }

  it "renders if passed token" do
    expect(location.virtual_line_on?).to be_falsey
    expect(appointment.link_token).to be_present
    expect do
      get "#{base_url}/#{appointment.id}"
    end.to raise_error(ActiveRecord::RecordNotFound)

    get "#{base_url}/#{appointment.link_token}"
    expect(response.status).to eq(200)
    expect(response).to render_template :show
    expect(assigns(:current_location)).to eq location
    expect(assigns(:current_organization)).to eq current_organization
    expect(assigns(:passive_organization)).to be_blank # because user isn't signed in
  end

  describe "create" do
    it "creates"
  end
end
