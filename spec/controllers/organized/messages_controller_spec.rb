require "spec_helper"

describe Organized::MessagesController, type: :controller do
  include_context :geocoder_default_location
  let(:root_path) { organization_messages_path(organization_id: organization.to_param, kind: kind_slug) }
  let(:user) { FactoryGirl.create(:organization_member, organization: organization) }
  let(:bike) { FactoryGirl.create(:bike, owner_email: "party_time@stuff.com") }
  let(:organization) { FactoryGirl.create(:organization, is_paid: false, geolocated_emails: true) }
  let(:paid_feature) { FactoryGirl.create(:paid_feature, feature_slugs: %w[messages geolocated_messages]) }
  let(:kind_slug) { "geolocated_messages" }
  let!(:invoice) do
    inv = FactoryGirl.create(:invoice_paid, organization: organization)
    inv.update_attributes(paid_feature_ids: [paid_feature&.id]) # Because we have to create the invoice first
    organization.update_attributes(updated_at: Time.now) # TODO: Rails 5 update - after_commit
    inv
  end

  before { set_current_user(user) if user.present? }

  describe "create" do
    let(:message_params) do
      {
        kind_slug: kind_slug,
        body: "some message text and stuff",
        bike_id: bike.to_param,
        latitude: default_location[:latitude],
        longitude: default_location[:longitude],
        accuracy: 12
      }
    end

    context "geolocated" do
      context "organization without geolocated messages" do
        let(:user) { FactoryGirl.create(:organization_admin, organization: organization) }
        let(:paid_feature) { nil }

        it "does not create" do
          expect(organization.is_paid).to be_truthy
          expect(organization.paid_for?(kind_slug)).to be_falsey
          expect do
            post :create, organization_id: organization.to_param, organization_message: message_params
            expect(response).to redirect_to organization_bikes_path(organization_id: organization.to_param)
            expect(flash[:error]).to be_present
          end.to_not change(OrganizationMessage, :count)
        end
      end

      context "organization with geolocated messages" do
        context "user without organization membership" do
          let(:user) { FactoryGirl.create(:confirmed_user) }
          it "does not create" do
            expect(organization.paid_for?(kind_slug)).to be_truthy
            expect do
              post :create, organization_id: organization.to_param, organization_message: message_params
              expect(response).to redirect_to user_home_url
              expect(flash[:error]).to be_present
            end.to_not change(OrganizationMessage, :count)
          end
        end

        context "without a required param" do
          it "fails and renders error" do
            request.env["HTTP_REFERER"] = bike_url(bike)
            expect do
              post :create, organization_id: organization.to_param, organization_message: message_params.except(:latitude)
              expect(response).to redirect_to bike_url(bike)
              expect(flash[:error]).to match(/location/i)
            end.to_not change(EmailOrganizationMessageWorker.jobs, :count)
          end
        end

        it "creates" do
          expect(organization.paid_for?(kind_slug)).to be_truthy
          expect do
            post :create, organization_id: organization.to_param, organization_message: message_params
            expect(response).to redirect_to root_path
            expect(flash[:success]).to be_present
          end.to change(EmailOrganizationMessageWorker.jobs, :count).by(1)
          organization_message = OrganizationMessage.last

          expect(organization_message.email).to eq "party_time@stuff.com"
          expect(organization_message.delivery_status).to eq nil
          expect(organization_message.sender).to eq user
          expect(organization_message.organization).to eq organization
          expect(organization_message.kind).to eq "geolocated"
          expect(organization_message.bike).to eq bike
          expect(organization_message.latitude).to eq message_params[:latitude]
          expect(organization_message.longitude).to eq message_params[:longitude]
          expect(organization_message.address).to eq default_location[:formatted_address]
          expect(organization_message.accuracy).to eq 12
        end
      end
    end
  end

  describe "index" do
    context "organization without geolocated messages" do
      let(:user) { FactoryGirl.create(:organization_admin, organization: organization) }
      let(:paid_feature) { nil }
      it "redirects" do
        expect(organization.paid_for?(kind_slug)).to be_falsey
        get :index, organization_id: organization.to_param
        expect(response).to redirect_to organization_bikes_path(organization_id: organization.to_param)
        expect(flash[:error]).to be_present
      end
    end
    it "renders" do
      expect(organization.paid_for?(kind_slug)).to be_truthy
      get :index, organization_id: organization.to_param, kind: "geolocated_messages"
      expect(response.status).to eq(200)
      expect(response).to render_template :index
      expect(response).to render_with_layout("application_revised")
      expect(assigns(:current_organization)).to eq organization
    end
  end

  describe "show" do
    let(:organization_message) { FactoryGirl.create(:organization_message, organization: organization) }
    it "renders" do
      get :show, organization_id: organization.to_param, id: organization_message.id
      expect(response.status).to eq(200)
      expect(response).to render_template :show
    end
  end
end
