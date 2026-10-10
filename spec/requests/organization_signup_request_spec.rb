require "rails_helper"

base_url = "/organizations/signup"
RSpec.describe OrganizationSignupController, type: :request do
  let(:start_params) { {name: "Shifty Bike Shop", kind: "bike_shop", email: "org_admin@bikeindex.org"} }
  let(:address) { {street: "10544 82 Ave NW", city: "Edmonton", postal_code: "T6E 2A4", country_id: Country.canada_id, region_string: "AB"} }
  let(:details_params) { {website: "shiftybikes.com", phone: "7183839999", publicly_visible: "1", address_record_attributes: address} }

  def organization_signup = OrganizationSignup.order(:id).last

  def confirm_params = {signup_token: organization_signup.id_token, confirmation_token: organization_signup.reload.email_confirmation_token}

  def welcome_path(organization, **) = welcome_organization_signup_path(organization_id: organization.to_param, **)

  it "creates the organization, and its admin's account, once the email is confirmed" do
    get "#{base_url}/new"
    expect(response).to redirect_to base_url
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
    expect(mail.html_part.decoded).to include "signup_token=#{organization_signup.id_token}"

    # Scanners follow the link, so it only renders the form that confirms
    get "#{base_url}/confirm", params: confirm_params
    expect(response.status).to eq 200
    expect(response.body).to include "Activate Shifty Bike Shop"
    expect(organization_signup.email_confirmed?).to be_falsey

    # The link just went out, so a bad one points at it rather than sending another
    expect {
      post "#{base_url}/confirm_email", params: confirm_params.merge(confirmation_token: "wrong")
    }.to_not change(EmailJobs::OrganizationSignupConfirmationJob.jobs, :size)
    expect(response).to redirect_to base_url
    expect(flash[:error]).to eq "That link doesn't work anymore. Use the newest email we sent to org_admin@bikeindex.org, or send another below."

    post "#{base_url}/confirm_email", params: confirm_params
    organization = Organization.last
    user = User.last
    expect(response).to redirect_to welcome_path(organization)
    expect(user).to have_attributes(email: "org_admin@bikeindex.org", confirmed?: true)
    expect(organization).to have_attributes(name: "Shifty Bike Shop", kind: "bike_shop", auto_user_id: user.id)
    expect(organization.locations.first.address_record).to have_attributes(address)
    expect(organization.organization_roles.pluck(:user_id, :role)).to eq([[user.id, "admin"]])
    expect(organization_signup.organization_id).to eq organization.id

    get response.location
    expect(response.status).to eq 200
    expect(response.body).to include "Shifty Bike Shop is active!"
    expect(response.body).to include new_register_url(organization_id: organization.slug)

    post "#{base_url}/confirm_email", params: confirm_params
    expect(response).to redirect_to organization_manage_path(organization_id: organization.to_param)
    expect(flash[:notice]).to eq "Shifty Bike Shop is already active"
    # And the session's signup is done - a bare visit starts another
    get base_url
    expect(response).to redirect_to "#{base_url}/new"
  end

  context "a link that doesn't work, once the last email is a while old" do
    let!(:organization_signup) { FactoryBot.create(:organization_signup_details_completed) }
    before do
      OrgServices::Signup.send_confirmation_email(organization_signup)
      organization_signup.update(email_confirmation_sent_at: 6.minutes.ago)
    end

    it "sends a new one, and the finished page can ask for one too" do
      expect {
        post "#{base_url}/confirm_email", params: confirm_params.merge(confirmation_token: "wrong")
      }.to change(EmailJobs::OrganizationSignupConfirmationJob.jobs, :size).by 1
      expect(flash[:error]).to eq "That link doesn't work anymore, so we've emailed a new one to org_admin@bikeindex.org."
      get "#{base_url}?step=finished"
      expect(response.body).to include "Send it again"

      expect { post "#{base_url}/resend" }.to_not change(EmailJobs::OrganizationSignupConfirmationJob.jobs, :size)
      expect(flash[:notice]).to match(/in the last few minutes/)

      organization_signup.update(email_confirmation_sent_at: 6.minutes.ago)
      expect { post "#{base_url}/resend" }.to change(EmailJobs::OrganizationSignupConfirmationJob.jobs, :size).by 1
      expect(response).to redirect_to "#{base_url}?step=finished"
      expect(flash[:success]).to eq "We've sent a new link to org_admin@bikeindex.org."
    end
  end

  it "picks the signup back up from any signup link, unless asked to start over" do
    get "#{base_url}/new"
    post base_url, params: {organization_signup: start_params}
    get "/organizations/new"
    expect(response).to redirect_to new_organization_signup_path
    get response.location
    expect(response).to redirect_to base_url
    get base_url
    expect(response).to redirect_to "#{base_url}?step=2"
    expect(OrganizationSignup.count).to eq 1

    get "#{base_url}?step=1"
    expect(response.body).to include "Start a different organization instead"
    get "#{base_url}/new", params: {restart: true}
    expect(OrganizationSignup.count).to eq 2
    get response.location
    expect(response).to redirect_to "#{base_url}?step=1"
  end

  context "the link clicked in another browser before step 2 is finished" do
    let!(:organization_signup) { FactoryBot.create(:organization_signup_started) }
    before { OrgServices::Signup.send_confirmation_email(organization_signup) }

    it "signs them in there to finish, and step 2 finished there creates the organization" do
      post "#{base_url}/confirm_email", params: confirm_params
      expect(response).to redirect_to "#{base_url}?step=2"
      expect(flash[:notice]).to be_blank
      expect(Organization.count).to eq 0
      expect(User.last.email).to eq "org_admin@bikeindex.org"

      get "#{base_url}?step=2"
      expect(response.body).to include "Your email is confirmed"
      patch base_url, params: {organization_signup: details_params}
      organization = Organization.last
      expect(response).to redirect_to welcome_path(organization)
      expect(organization.organization_roles.first.user_id).to eq User.last.id
    end
  end

  it "creates the organization when step 2 is finished in the browser that started it, after the link was clicked elsewhere" do
    get "#{base_url}/new"
    post base_url, params: {organization_signup: start_params}
    phone = open_session
    phone.post "#{base_url}/confirm_email", params: confirm_params
    # redirect_to matches the example's own session, so the phone's is read off its response
    expect(phone.response.location).to eq "http://www.example.com#{base_url}?step=2"

    patch base_url, params: {organization_signup: details_params}
    organization = Organization.last
    expect(organization.organization_roles.first.user.email).to eq "org_admin@bikeindex.org"
    expect(response).to redirect_to new_session_path
    expect(flash[:notice]).to eq "Shifty Bike Shop is active! Sign in as org_admin@bikeindex.org to manage it."

    # And the phone, still on step 2, goes to the organization
    phone.get "#{base_url}?step=2"
    expect(phone.response.location).to eq organization_manage_url(organization_id: organization.to_param)
  end

  context "the name is taken before the link is clicked" do
    let!(:organization_signup) { FactoryBot.create(:organization_signup_details_completed) }
    before do
      OrgServices::Signup.send_confirmation_email(organization_signup)
      FactoryBot.create(:organization, name: "Shifty Bike Shop")
    end

    it "says so, and renaming finishes it" do
      post "#{base_url}/confirm_email", params: confirm_params
      expect(response).to redirect_to "#{base_url}?step=1"
      expect(flash[:error]).to match(/Another organization took the name Shifty Bike Shop/)

      post base_url, params: {organization_signup: start_params.merge(name: "Shifty Bikes East")}
      organization = Organization.last
      expect(organization.name).to eq "Shifty Bikes East"
      expect(response).to redirect_to welcome_path(organization)
    end
  end

  context "the link clicked again in a browser that isn't signed in" do
    let!(:organization_signup) { FactoryBot.create(:organization_signup_details_completed) }
    before { OrgServices::Signup.send_confirmation_email(organization_signup) }

    it "says the organization is active and asks to sign in" do
      token = organization_signup.reload.email_confirmation_token
      post "#{base_url}/confirm_email", params: confirm_params
      delete "/session"
      get "#{base_url}/confirm", params: {signup_token: organization_signup.id_token, confirmation_token: token}
      expect(response).to redirect_to new_session_path
      expect(flash[:notice]).to eq "Shifty Bike Shop is active! Sign in as org_admin@bikeindex.org to manage it."
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
      expect(organization_signup.email).to eq current_user.email
      patch base_url, params: {organization_signup: details_params}
      expect(response).to redirect_to "#{base_url}?step=finished"
      expect(Organization.count).to eq 0

      post "#{base_url}/confirm_email", params: confirm_params
      organization = Organization.last
      expect(response).to redirect_to welcome_path(organization)
      expect(organization.organization_roles.first.user_id).to eq current_user.id
    end

    context "arriving from lightspeed_interface" do
      it "offers the way back there once the organization exists" do
        get "/lightspeed_interface"
        get response.location
        post base_url, params: {organization_signup: start_params}
        patch base_url, params: {organization_signup: details_params}
        post "#{base_url}/confirm_email", params: confirm_params
        organization = Organization.last
        expect(response).to redirect_to welcome_path(organization, return_to: lightspeed_interface_path)
        get response.location
        expect(response.body).to include "Continue where you were"
        expect(response.body).to include %(href="#{lightspeed_interface_path}")
      end
    end

    context "as someone other than the address emailed" do
      let!(:organization_signup) { FactoryBot.create(:organization_signup_details_completed) }
      before { OrgServices::Signup.send_confirmation_email(organization_signup) }

      it "doesn't spend the link until they choose to sign out" do
        token = organization_signup.reload.email_confirmation_token
        get "#{base_url}/confirm", params: confirm_params
        expect(response.body).to include "Sign out and activate"

        post "#{base_url}/confirm_email", params: confirm_params
        expect(response).to redirect_to "#{base_url}/confirm?confirmation_token=#{token}&signup_token=#{organization_signup.id_token}"
        expect(flash[:error]).to match(current_user.email)
        expect(organization_signup.reload.email_confirmed?).to be_falsey

        post "#{base_url}/confirm_email", params: confirm_params.merge(confirmation_token: token, sign_out: true)
        organization = Organization.last
        expect(organization.organization_roles.first.user.email).to eq "org_admin@bikeindex.org"
        expect(response).to redirect_to welcome_path(organization)
      end
    end
  end

  context "an unknown link" do
    it "starts a new signup" do
      get "#{base_url}/confirm", params: {signup_token: "unknown", confirmation_token: "x"}
      expect(response).to redirect_to "#{base_url}/new?restart=true"
    end
  end
end
