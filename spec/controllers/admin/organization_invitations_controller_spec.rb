require "rails_helper"

RSpec.describe Admin::OrganizationInvitationsController, type: :controller do
  let(:user) { FactoryBot.create(:admin) }
  before do
    set_current_user(user)
  end
  describe "index" do
    it "responds with OK and renders the index template" do
      get :index
      expect(response).to be_ok
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end
  describe "new" do
    it "responds with OK and renders the new template" do
      get :new
      expect(response).to be_ok
      expect(response.status).to eq(200)
      expect(response).to render_template(:new)
    end
  end
  describe "create" do
    context "valid create" do
      let!(:organization) { FactoryBot.create(:organization) }
      let(:valid_attrs) { { organization_id: organization.id, invitee_email: user.email } }
      it "creates an invite" do
        expect do
          post :create, organization_invitation: valid_attrs
        end.to change(OrganizationInvitation, :count).by 1
        expect(response).to redirect_to admin_organization_url(organization)
      end
    end
    context "Organization is out of invites" do
      let!(:organization) { FactoryBot.create(:organization, available_invitation_count: 0) }
      let(:valid_attrs) { { organization_id: organization.id, invitee_email: user.email } }
      it "redirects back to new invite template" do
        expect do
          post :create, organization_invitation: valid_attrs
        end.to_not change(OrganizationInvitation, :count)
        expect(response).to redirect_to admin_organization_path(organization)
      end
    end
  end
end
