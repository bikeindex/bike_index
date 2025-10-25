require "rails_helper"

# Need controller specs to test setting session
#
# PUT ALL TESTS IN Request spec !
#
RSpec.describe Organized::BikesController, type: :controller do
  context "given an authenticated ambassador" do
    include_context :logged_in_as_ambassador
    it "redirects to the organization root path" do
      expect(get(:index, params: {organization_id: organization})).to redirect_to(organization_root_path)
      expect(get(:recoveries, params: {organization_id: organization})).to redirect_to(organization_root_path)
      expect(get(:incompletes, params: {organization_id: organization})).to redirect_to(organization_root_path)
      expect(get(:new, params: {organization_id: organization})).to redirect_to(organization_root_path)
      expect(post(:resend_incomplete_email, params: {organization_id: organization, id: 12})).to redirect_to(organization_root_path)
    end
    describe "multi_serial_search" do
      it "renders" do
        get :multi_serial_search, params: {organization_id: organization.to_param}
        expect(response.status).to eq(200)
        expect(response).to render_template :multi_serial_search
      end
    end
  end

  let(:non_organization_bike) { FactoryBot.create(:bike) }
  before do
    expect(non_organization_bike).to be_present
  end

  context "not organization member" do
    include_context :logged_in_as_user
    let!(:organization) { FactoryBot.create(:organization) }
    it "redirects the user, reassigns passive_organization_id" do
      session[:passive_organization_id] = "0" # Because, who knows! Maybe they don't have org access at some point.
      get :index, params: {organization_id: organization.to_param}
      expect(response.location).to eq my_account_url
      expect(flash[:error]).to be_present
      expect(session[:passive_organization_id]).to eq "0" # sets it to zero so we don't look it up again
    end
    context "admin user" do
      let(:user) { FactoryBot.create(:superuser) }
      it "renders, doesn't reassign passive_organization_id" do
        session[:passive_organization_id] = organization.to_param # Admin, so user has access
        get :index, params: {organization_id: organization.to_param}
        expect(response.status).to eq(200)
        expect(response).to render_template :index
        expect(assigns(:current_organization)).to eq organization
        expect(assigns(:page_id)).to eq "organized_bikes_index"
        expect(assigns(:passive_organization)).to eq organization
        expect(session[:passive_organization_id]).to eq organization.id
      end
    end
  end

  context "logged_in_as_organization_admin" do
    include_context :logged_in_as_organization_admin
    describe "index" do
      it "renders" do
        get :index, params: {organization_id: organization.to_param}
        expect(response.status).to eq(200)
        expect(response).to render_template :index
        expect(assigns(:current_organization)).to eq organization
        expect(assigns(:page_id)).to eq "organized_bikes_index"
      end
    end

    describe "new" do
      it "renders" do
        get :new, params: {organization_id: organization.to_param}
        expect(response.status).to eq(200)
        expect(response).to render_template :new
        expect(assigns(:current_organization)).to eq organization
        expect(response.headers["X-Frame-Options"]).to eq "SAMEORIGIN"
      end
    end

    describe "new_iframe" do
      it "renders" do
        get :new_iframe, params: {organization_id: organization.to_param}
        expect(response.status).to eq(200)
        expect(response).to render_template :new_iframe
        expect(assigns(:current_organization)).to eq organization
        expect(assigns(:bike)&.creation_organization_id).to eq organization.id
        expect(response.headers["X-Frame-Options"]).to be_blank
      end
    end

    describe "create" do
      let(:manufacturer) { FactoryBot.create(:manufacturer) }
      let(:color) { FactoryBot.create(:color) }
      let(:attrs) do
        {
          manufacturer_id: manufacturer.id,
          owner_email: "something@sss.com",
          creator_id: 21,
          primary_frame_color_id: color.id,
          creation_organization_id: 9292,
          serial_number: "xcxcxcxcc7xcx"
        }
      end
      it "creates" do
        Sidekiq::Job.clear_all
        ActionMailer::Base.deliveries = []
        expect(organization.auto_user_id).to_not eq user.id
        expect(UpdateMailchimpDatumJob).to be_present
        stub_const("UpdateMailchimpDatumJob::UPDATE_MAILCHIMP", false)
        Sidekiq::Testing.inline! do
          expect {
            post :create, params: {bike: attrs, organization_id: organization.to_param}
          }.to change(Bike, :count).by 1
        end
        expect(response.headers["X-Frame-Options"]).to be_blank

        b_param = BParam.reorder(:created_at).last
        expect(b_param.owner_email).to eq attrs[:owner_email]
        expect(b_param.owner_email).to eq attrs[:owner_email]
        expect(b_param.creation_organization_id).to eq organization.id
        expect(b_param.bike["serial_number"]).to eq attrs[:serial_number]

        bike = b_param.created_bike
        expect(bike.status).to eq "status_with_owner"
        expect(bike.serial_number).to eq attrs[:serial_number]
        expect(bike.id).to eq b_param.created_bike_id
        expect(bike.creator_id).to eq user.id
        expect(bike.organizations.pluck(:id)).to eq([organization.id])
        expect(bike.editable_organizations.pluck(:id)).to eq([organization.id])
        expect(bike.creation_organization_id).to eq organization.id
        expect(bike.manufacturer_id).to eq manufacturer.id
        expect(bike.current_ownership.origin).to eq "organization_form"
        expect(bike.primary_frame_color_id).to eq color.id
        expect(bike.secondary_frame_color_id).to be_blank
        expect(bike.tertiary_frame_color_id).to be_blank

        expect(ActionMailer::Base.deliveries.count).to eq 1
        message = ActionMailer::Base.deliveries.last
        expect(message.to).to eq([attrs[:owner_email]])
        expect(message.subject).to match(/confirm.*registration/i)
      end
    end
  end
end
