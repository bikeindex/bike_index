require "spec_helper"

describe OrganizationInvitationsController do
  describe :new do 
    before do 
      ApplicationController.any_instance.should_receive(:require_admin!).and_return(true)
      post :new
    end
    it { should respond_with(:success) }
    it { should render_template(:new) }
    it { should_not set_the_flash }
  end

  describe :create do
    before :each do
      @user = FactoryGirl.create(:user)
      @organization = FactoryGirl.create(:organization, available_invitation_count: 1)
    end
    
    it "should create a new organization_invitation" do
      controller.should_receive(:require_admin!).and_return(true)
      controller.should_receive(:current_organization).and_return(@organization)
      @organization_invitation = FactoryGirl.create(:organization_invitation, {inviter_id: @user.id, organization_id: @organization.id, invitee_email: "bike_email@bike_shop.com"})
      session[:user_id] = @user.id
      lambda {
        post :create, organization_invitation: { 
          inviter_id: @user.id,
          membership_role: "member",
          invitee_email: "bike_email@bike_shop.com"
        }
      }.should change(OrganizationInvitation, :count).by(1)
    end

    it "should reduce the number of invitation tokens for the organization by one and increase the invitations sent by one" do
      controller.should_receive(:require_admin!).and_return(true)
      controller.should_receive(:current_organization).and_return(@organization)
      @organization_invitation = FactoryGirl.create(:organization_invitation, {inviter_id: @user.id, organization_id: @organization.id, invitee_email: "bike_email@bike_shop.com"})
      session[:user_id] = @user.id
      lambda {
        post :create, organization_invitation: { 
          inviter_id: @user.id,
          membership_role: "member",
          invitee_email: "bike_email@bike_shop.com"
        }
      }.should change(OrganizationInvitation, :count).by(1)
      @organization.reload.available_invitation_count.should eq(0)
      @organization.sent_invitation_count.should eq(1)
    end

    it "should not create a new organization_invitation if there are no available invitations" do
      controller.should_receive(:require_admin!).and_return(true)
      controller.should_receive(:current_organization).and_return(@organization)
      @organization.available_invitation_count = 0
      @organization_invitation = FactoryGirl.create(:organization_invitation, {inviter_id: @user.id, organization_id: @organization.id, invitee_email: "bike_email@bike_shop.com"})
      lambda {
        post :create, organization_invitation: { 
          inviter_id: @user.id,
          membership_role: "member",
          invitee_email: "bike_email@bike_shop.com"
        }
      }.should_not change(OrganizationInvitation, :count).by(1)
    end
  end


end
