require "rails_helper"

base_url = "/organizations/signup"
RSpec.describe OrganizationSignupController, type: :request do
  let(:start_params) { {name: "Shifty Bike Shop", kind: "bike_shop", email: "org_admin@bikeindex.org"} }
  let(:address) { {street: "10544 82 Ave NW", city: "Edmonton", postal_code: "T6E 2A4", country_id: Country.canada_id, region_string: "AB"} }
  let(:details_params) { {website: "shiftybikes.com", phone: "7183839999", publicly_visible: "1", address_record_attributes: address} }

  def organization_signup = OrganizationSignup.order(:id).last

  it "creates the organization, and its admin's account, once the email is confirmed" do
    get "/organizations/new"
    expect(response).to redirect_to "#{base_url}/new"
    get "#{base_url}/new"
    expect(response).to redirect_to "#{base_url}?step=1"
    get "#{base_url}?step=2"
    expect(response).to redirect_to "#{base_url}?step=1"
    get "#{base_url}?step=1"
    expect(response.status).to eq 200
    expect(response.body).to include "Add your organization"

    expect {
      post base_url, params: {organization_signup: start_params.merge(name: "")}
    }.to_not change(EmailJobs::OrganizationSignupConfirmationJob.jobs, :size)
    expect(response.status).to eq 422
    expect(response.body).to include "Organization name is required"

    expect {
      post base_url, params: {organization_signup: start_params}
    }.to change(EmailJobs::OrganizationSignupConfirmationJob.jobs, :size).by 1
    expect(response).to redirect_to "#{base_url}?step=2"
    get "#{base_url}?step=2"
    expect(response.body).to include "a link to activate the organization"

    patch base_url, params: {organization_signup: details_params.merge(address_record_attributes: address.except(:street))}
    expect(response.status).to eq 422
    expect(response.body).to include "Please enter the organization&#39;s full address"

    patch base_url, params: {organization_signup: details_params}
    expect(response).to redirect_to "#{base_url}?step=finished"
    get "#{base_url}?step=finished"
    expect(response.body).to include "Check your email"
    expect(Organization.count).to eq 0
    expect(User.count).to eq 0

    ActionMailer::Base.deliveries = []
    EmailJobs::OrganizationSignupConfirmationJob.drain
    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq(["org_admin@bikeindex.org"])
    expect(mail.subject).to eq "Confirm your email to activate Shifty Bike Shop on Bike Index"
    token = organization_signup.email_confirmation_token
    expect(mail.html_part.decoded).to include "signup_token=#{organization_signup.id_token}"

    # Scanners follow the link, so it only renders the form that confirms
    get "#{base_url}/confirm", params: {signup_token: organization_signup.id_token, confirmation_token: token}
    expect(response.status).to eq 200
    expect(response.body).to include "Activate Shifty Bike Shop"
    expect(organization_signup.email_confirmed?).to be_falsey

    post "#{base_url}/confirm_email", params: {signup_token: organization_signup.id_token, confirmation_token: "wrong"}
    expect(response).to redirect_to base_url
    expect(flash[:error]).to match(/expired/)
    expect(Organization.count).to eq 0

    post "#{base_url}/confirm_email", params: {signup_token: organization_signup.id_token, confirmation_token: token}
    organization = Organization.last
    user = User.last
    expect(response).to redirect_to organization_manage_path(organization_id: organization.to_param)
    expect(user).to have_attributes(email: "org_admin@bikeindex.org", confirmed?: true)
    expect(organization).to have_attributes(name: "Shifty Bike Shop", kind: "bike_shop", auto_user_id: user.id)
    expect(organization.locations.first.address_record).to have_attributes(address)
    expect(organization.organization_roles.pluck(:user_id, :role)).to eq([[user.id, "admin"]])
    expect(organization_signup.organization_id).to eq organization.id

    # Signed in as the admin
    get organization_manage_path(organization_id: organization.to_param)
    expect(response.status).to eq 200

    # The link again goes to the organization
    post "#{base_url}/confirm_email", params: {signup_token: organization_signup.id_token, confirmation_token: token}
    expect(response).to redirect_to organization_manage_path(organization_id: organization.to_param)
    expect(Organization.count).to eq 1
    # And the session's signup is done - a bare visit starts another
    get base_url
    expect(response).to redirect_to "#{base_url}/new"
  end

  context "the link clicked before step 2 is finished" do
    let!(:organization_signup) { FactoryBot.create(:organization_signup_started) }
    before { OrgServices::Signup.send_confirmation_email(organization_signup) }

    it "signs them in to finish, and step 2 creates the organization" do
      post "#{base_url}/confirm_email", params: {signup_token: organization_signup.id_token,
                                                 confirmation_token: organization_signup.reload.email_confirmation_token}
      expect(response).to redirect_to "#{base_url}?step=2"
      expect(Organization.count).to eq 0
      expect(User.last.email).to eq "org_admin@bikeindex.org"

      get "#{base_url}?step=2"
      expect(response.body).to_not include "a link to activate the organization"
      patch base_url, params: {organization_signup: details_params}
      organization = Organization.last
      expect(response).to redirect_to organization_manage_path(organization_id: organization.to_param)
      expect(organization.organization_roles.first.user_id).to eq User.last.id
    end
  end

  context "signed in" do
    include_context :request_spec_logged_in_as_user

    it "uses their email, and still waits on the link" do
      get "#{base_url}/new"
      get "#{base_url}?step=1"
      expect(response.body).to include current_user.email
      expect(response.body).to_not include "organization_signup[email]"
      post base_url, params: {organization_signup: start_params}
      expect(organization_signup).to have_attributes(email: current_user.email, creator_id: current_user.id)
      patch base_url, params: {organization_signup: details_params}
      expect(response).to redirect_to "#{base_url}?step=finished"
      expect(Organization.count).to eq 0

      OrgServices::Signup.send_confirmation_email(organization_signup)
      post "#{base_url}/confirm_email", params: {signup_token: organization_signup.id_token,
                                                 confirmation_token: organization_signup.email_confirmation_token}
      organization = Organization.last
      expect(response).to redirect_to organization_manage_path(organization_id: organization.to_param)
      expect(organization.organization_roles.first.user_id).to eq current_user.id
    end

    context "arriving from lightspeed_interface" do
      it "goes back there once the organization exists" do
        get "/lightspeed_interface"
        get "#{base_url}/new"
        post base_url, params: {organization_signup: start_params}
        patch base_url, params: {organization_signup: details_params}
        post "#{base_url}/confirm_email", params: {signup_token: organization_signup.id_token,
                                                   confirmation_token: organization_signup.email_confirmation_token}
        expect(Organization.count).to eq 1
        expect(response).to redirect_to lightspeed_interface_path
      end
    end

    context "as someone other than the address emailed" do
      let!(:organization_signup) { FactoryBot.create(:organization_signup_details_completed) }
      before { OrgServices::Signup.send_confirmation_email(organization_signup) }

      it "doesn't spend the link" do
        token = organization_signup.reload.email_confirmation_token
        post "#{base_url}/confirm_email", params: {signup_token: organization_signup.id_token, confirmation_token: token}
        expect(response).to redirect_to "#{base_url}/confirm?confirmation_token=#{token}&signup_token=#{organization_signup.id_token}"
        expect(flash[:error]).to match(current_user.email)
        expect(organization_signup.reload.email_confirmed?).to be_falsey
        expect(Organization.count).to eq 0
      end
    end
  end

  context "an unknown link" do
    it "starts a new signup" do
      get "#{base_url}/confirm", params: {signup_token: "unknown", confirmation_token: "x"}
      expect(response).to redirect_to "#{base_url}/new"
    end
  end
end
