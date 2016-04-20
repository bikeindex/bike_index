require "spec_helper"

describe OrganizationInvitationsController do
  describe 'new' do
    it 'renders the page' do
      user = FactoryGirl.create(:user, email: 'MEMBERSTHING@ggg.com')
      organization = FactoryGirl.create(:organization, available_invitation_count: 1)
      membership = FactoryGirl.create(:membership, organization: organization, user: user, role: "admin")
      set_current_user(user)
      { put: "/organizations/#{organization.slug}/organization_invitations/new" }
      expect(response.code).to eq("200")
    end
  end

  describe 'create' do
    before :each do
      @user = FactoryGirl.create(:user)
      @organization = FactoryGirl.create(:organization, available_invitation_count: 1)
      @membership = FactoryGirl.create(:membership, organization: @organization, user: @user, role: "admin")
      set_current_user(@user)
    end
    
    it "creates a new organization_invitation and reduce the organization invitation tokens by one" do
      expect do
        put :create, organization_id: @organization.slug, organization_invitation: { 
          inviter_id: @user.id,
          membership_role: "member",
          invitee_email: "bike_email@bike_shop.com"
        }
      end.to change(OrganizationInvitation, :count).by(1)
      expect(@organization.reload.available_invitation_count).to eq(0)
      expect(@organization.sent_invitation_count).to eq(1)
    end

    it 'does not create a new organization_invitation if there are no available invitations' do
      @organization.update_attributes(available_invitation_count: 0)
      expect do
        put :create, organization_id: @organization.slug, organization_invitation: { 
          inviter_id: @user.id,
          membership_role: 'member',
          invitee_email: 'bike_email@bike_shop.com'
        }
      end.to change(OrganizationInvitation, :count).by(0)
    end
  end
end
