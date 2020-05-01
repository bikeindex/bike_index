require "rails_helper"

RSpec.describe Organized::EmailsController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/emails" }
  # we need a default organized bike to render emails, so build one
  let(:ownership) { FactoryBot.create(:ownership_organization_bike, organization: current_organization) }
  let!(:bike) { ownership.bike }

  context "logged_in_as_organization_member" do
    include_context :request_spec_logged_in_as_organization_member
    describe "index" do
      it "redirects to the organization root path" do
        get base_url
        expect(response).to redirect_to(organization_root_path)
        expect(flash[:error]).to be_present
      end
    end

    describe "show" do
      context "appears_abandoned_notification" do
        let!(:parking_notification) do
          FactoryBot.create(:parking_notification_organized,
                            organization: current_organization,
                            kind: "appears_abandoned_notification",
                            bike: bike)
        end
        it "renders" do
          get "#{base_url}/appears_abandoned_notification"
          expect(response.status).to eq(200)
          expect(response).to render_template("organized_mailer/parking_notification")
          expect(assigns(:parking_notification)).to eq parking_notification
          expect(parking_notification.retrieval_link_token).to be_present
          expect(assigns(:retrieval_link_url)).to eq "#"
        end
      end
    end

    describe "edit" do
      it "redirects to the organization root path" do
        get "#{base_url}/appears_abandoned_notification/edit"
        expect(response).to redirect_to(organization_root_path)
        expect(flash[:error]).to be_present
      end
    end
  end

  context "logged_in_as_organization_admin" do
    include_context :request_spec_logged_in_as_organization_admin
    describe "index" do
      it "renders" do
        get base_url
        expect(response).to render_template(:index)
      end
    end

    describe "show" do
      let(:current_organization) { FactoryBot.create(:current_organization, :in_nyc) }
      context "appears_abandoned_notification" do
        xit "renders" do
          expect(current_organization.parking_notifications.appears_abandoned_notification.count).to eq 0
          get "#{base_url}/appears_abandoned_notification"
          expect(response.status).to eq(200)
          expect(response).to render_template("organized_mailer/parking_notification")
          expect(assigns(:parking_notification).is_a?(ParkingNotification)).to be_truthy
          expect(parking_notification.retrieval_link_token).to be_present
          expect(assigns(:retrieval_link_url)).to eq "#"
        end
      end
    end

    describe "edit" do
      xit "redirects to the organization root path" do
        get "#{base_url}/appears_abandoned_notification/edit"
        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
      end
    end

    describe "update" do
      it "creates" do
        expect(current_organization.mail_snippets.count).to eq 0
        put "#{base_url}/impound_notification", params: {
          organization_id: current_organization.to_param,
          id: "impound_notification",
          mail_snippet: {
            body: "cool new things",
            is_enabled: "true",
          }
        }
        expect(current_organization.mail_snippets.count).to eq 1
        mail_snippet = current_organization.mail_snippets.last
        expect(mail_snippet.kind).to eq "impound_notification"
        expect(mail_snippet.body).to eq "cool new things"
        expect(mail_snippet.is_enabled).to be_truthy
      end
    end
  end
end
