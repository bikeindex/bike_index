require "spec_helper"

RSpec.describe Admin::OrganizationInvitationsController, type: :controller do
  let(:user) { FactoryBot.create(:admin) }
  let(:organization_invitation) { FactoryBot.create(:organization_invitation) }
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
    it "creates a new invite" do
      invite = FactoryBot.attributes_for(:organization_invitation)
      expect(OrganizationInvitation.count).to eq(0)
      post :create, organization_invitation: invite
      expect(response).to redirect_to(admin_ambassador_tasks_url)
      expect(flash).to_not be_present
      expect(OrganizationInvitation.count).to eq(1)
    end
  end
end
