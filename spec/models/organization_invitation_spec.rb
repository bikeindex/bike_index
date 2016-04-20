require "spec_helper"

describe OrganizationInvitation do
  describe 'validations' do
    it { is_expected.to belong_to :inviter }
    it { is_expected.to belong_to :invitee }
    it { is_expected.to validate_presence_of :invitee_email }
    it { is_expected.to validate_presence_of :organization }
    it { is_expected.to validate_presence_of :inviter }
    it { is_expected.to validate_presence_of :membership_role }
  end  

  describe 'create' do
    before :each do
      @o = FactoryGirl.create(:organization_invitation)
    end

    it "creates a valid organization_invitation" do
      expect(@o.valid?).to be_truthy
    end

    it "assigns to user if the user exists" do
      @user = FactoryGirl.create(:user)
      @o1 = FactoryGirl.create(:organization_invitation, invitee_email: @user.email)
      expect(@user.memberships.count).to eq(1)
      expect(@o1.redeemed).to be_truthy
    end
  end

  it "enqueues an email job" do
    expect {
      FactoryGirl.create(:organization_invitation)
    }.to change(EmailOrganizationInvitationWorker.jobs, :size).by(1)
  end

  describe 'normalize_email' do
    it "removes leading and trailing whitespace and downcase email" do
      oi = OrganizationInvitation.new 
      allow(oi).to receive(:invitee_email).and_return("   SomE@dd.com ")
      expect(oi.normalize_email).to eq("some@dd.com")
    end
  end
  

  describe "assign_to(user)" do

    before :each do
      @organization = FactoryGirl.create(:organization)
      @o = FactoryGirl.create(:organization_invitation, organization: @organization, invitee_email: "EMAIL@email.com")
      @user = FactoryGirl.create(:user, email: "EMAIL@email.com")
    end

    it "sets the user if the email does match" do
      @o.assign_to(@user)
      expect(@o.invitee.id).to eq(@user.id)
    end

    it "sets the user's name if the name is blank" do
      @user2 = FactoryGirl.create(:user, name: nil)
      @o2 = FactoryGirl.create(:organization_invitation, organization: @organization, invitee_email: @user2.email, invitee_name: "Biker Name")
      @o2.assign_to(@user2)
      expect(@user2.reload.name).to eq("Biker Name")
    end

    it "is not able to be used again once it has been redeemed" do
      @o.assign_to(@user)
      @o.assign_to(@user)
      expect(@user.memberships.count).to eq(1)
    end

    it "redeems the invitation" do
      @o.assign_to(@user)
      expect(@o.redeemed).to be_truthy
    end

    it "does not let users have more than one membership to a single organization" do
      FactoryGirl.create(:membership, organization: @organization, user: @user)
      # pp @user.organizations
      @o.assign_to(@user)
      expect(@user.memberships.count).to eq(1)
    end

    it "lets users have multiple memberships to different organizations" do
      @organization2 = FactoryGirl.create(:organization)
      FactoryGirl.create(:membership, organization: @organization2, user: @user)
      @o.assign_to(@user)
      expect(@user.memberships.count).to eq(2)
    end
    
    it "creates a membership on assignment" do
      @o2 = FactoryGirl.create(:organization_invitation, organization: @organization, invitee_email: "George@gma.com")
      @user2 = FactoryGirl.create(:user, email: "george@gma.com")
      expect {
        @o2.assign_to(@user2)
      }.to change(Membership, :count).by(1)
    end
  end

end
