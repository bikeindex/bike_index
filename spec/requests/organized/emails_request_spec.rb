require "rails_helper"

RSpec.describe Organized::EmailsController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/emails" }
  # we need a default organized bike to render emails, so build one
  let(:ownership) { FactoryBot.create(:ownership_organization_bike, organization: current_organization) }
  let(:enabled_feature_slugs) { %w[show_partial_registrations parking_notifications graduated_notifications customize_emails] }
  let!(:bike) { ownership.bike }

  context "logged_in_as_organization_member" do
    include_context :request_spec_logged_in_as_organization_member
    let(:current_organization) { FactoryBot.create(:organization_with_paid_features, :in_nyc, enabled_feature_slugs: enabled_feature_slugs) }
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
    let(:current_organization) { FactoryBot.create(:organization_with_paid_features, :in_nyc, enabled_feature_slugs: enabled_feature_slugs) }
    let(:all_viewable_email_kinds) { %w[finished_registration partial_registration appears_abandoned_notification parked_incorrectly_notification impound_notification graduated_notification] }
    describe "index" do
      it "renders" do
        get base_url
        expect(response).to render_template(:index)
        expect(assigns(:viewable_email_kinds)).to match_array(all_viewable_email_kinds)
      end
    end

    describe "show" do
      context "appears_abandoned_notification" do
        it "renders" do
          expect(current_organization.parking_notifications.appears_abandoned_notification.count).to eq 0
          get "#{base_url}/appears_abandoned_notification"
          expect(response.status).to eq(200)
          expect(response).to render_template("organized_mailer/parking_notification")
          expect(assigns(:parking_notification).is_a?(ParkingNotification)).to be_truthy
          expect(assigns(:parking_notification).retrieval_link_token).to be_blank
          expect(assigns(:retrieval_link_url)).to eq "#"
          expect(assigns(:kind)).to eq "appears_abandoned_notification"
          current_organization.reload
          expect(current_organization.parking_notifications.appears_abandoned_notification.count).to eq 0
        end
      end
      context "passed id" do
        let!(:parking_notification) { FactoryBot.create(:parking_notification, organization: current_organization, kind: "parked_incorrectly_notification") }
        it "renders passed id" do
          get "#{base_url}/parked_incorrectly_notification", params: { parking_notification_id: parking_notification.id }
          expect(response.status).to eq(200)
          expect(response).to render_template("organized_mailer/parking_notification")
          expect(assigns(:parking_notification)).to eq parking_notification
          expect(assigns(:retrieval_link_url)).to eq "#"
          expect(assigns(:kind)).to eq "parked_incorrectly_notification"
        end
        context "different org" do
          let!(:parking_notification) { FactoryBot.create(:parking_notification) }
          it "404s" do
            expect do
              get "#{base_url}/appears_abandoned_notification", params: { parking_notification_id: parking_notification.id }
            end.to raise_error(ActiveRecord::RecordNotFound)
          end
        end
      end
      context "graduated_notification passed id" do
        let!(:graduated_notification) { FactoryBot.create(:graduated_notification, organization: current_organization) }
        it "renders" do
          get "#{base_url}/graduated_notification", params: { graduated_notification_id: graduated_notification.id }
          expect(response.status).to eq(200)
          expect(response).to render_template("organized_mailer/graduated_notification")
          expect(assigns(:graduated_notification).id).to eq graduated_notification.id
          expect(assigns(:retrieval_link_url)).to eq "#"
          expect(assigns(:kind)).to eq "graduated_notification"
        end
        context "different org" do
          let!(:graduated_notification) { FactoryBot.create(:graduated_notification) }
          it "404s" do
            expect do
              get "#{base_url}/graduated_notification", params: { graduated_notification_id: graduated_notification.id }
            end.to raise_error(ActiveRecord::RecordNotFound)
          end
        end
      end
      context "finished_registration" do
        let(:enabled_feature_slugs) { %w[customize_emails] }
        it "renders" do
          get "#{base_url}/finished_registration"
          expect(response.status).to eq(200)
          expect(response).to render_template("organized_mailer/finished_registration")
          expect(assigns(:viewable_email_kinds)).to eq(["finished_registration"])
          # And it defaults to finished registration, if unable to parse kind
          get "#{base_url}/whateverrrrr"
          expect(response.status).to eq(200)
          expect(response).to render_template("organized_mailer/finished_registration")
          expect(assigns(:viewable_email_kinds)).to eq(["finished_registration"])
        end
      end
      context "partial_registration" do
        let(:enabled_feature_slugs) { %w[customize_emails show_partial_registrations graduated_notifications] }
        it "renders" do
          get "#{base_url}/partial_registration"
          expect(response.status).to eq(200)
          expect(response).to render_template("organized_mailer/partial_registration")
          expect(assigns(:viewable_email_kinds)).to match_array(%w[finished_registration partial_registration graduated_notification])
        end
      end
    end

    describe "edit" do
      it "renders" do
        all_viewable_email_kinds.each do |kind|
          get "#{base_url}/#{kind}/edit"
          expect(response.status).to eq(200)
          expect(response).to render_template(:edit)
          expect(assigns(:kind)).to eq kind
          unless %w[partial_registration finished_registration].include?(kind)
            expect(assigns(:can_edit)).to be_truthy
          end
        end
      end
    end

    describe "update" do
      it "creates" do
        expect(current_organization.mail_snippets.count).to eq 0
        put "#{base_url}/impound_notification", params: {
                                                  organization_id: current_organization.to_param,
                                                  id: "impound_notification",
                                                  mail_snippet: {
                                                    subject: "a fancy custom subject",
                                                    body: "cool new things",
                                                    is_enabled: "true",
                                                  },
                                                }
        expect(current_organization.mail_snippets.count).to eq 1
        mail_snippet = current_organization.mail_snippets.last
        expect(mail_snippet.kind).to eq "impound_notification"
        expect(mail_snippet.body).to eq "cool new things"
        expect(mail_snippet.subject).to eq "a fancy custom subject"
        expect(mail_snippet.is_enabled).to be_truthy
      end
      context "existing" do
        let!(:mail_snippet) do
          FactoryBot.create(:mail_snippet,
                            kind: "appears_abandoned_notification",
                            organization: current_organization,
                            is_enabled: true,
                            body: "party")
        end
        it "updates" do
          expect(current_organization.mail_snippets.count).to eq 1
          put "#{base_url}/appears_abandoned_notification", params: {
                                                    organization_id: current_organization.to_param,
                                                    id: "appears_abandoned_notification",
                                                    mail_snippet: {
                                                      subject: "a fancy custom subject",
                                                      body: "cool new things",
                                                      is_enabled: "0",
                                                    },
                                                  }
          expect(current_organization.mail_snippets.count).to eq 1
          mail_snippet.reload
          expect(mail_snippet.kind).to eq "appears_abandoned_notification"
          expect(mail_snippet.body).to eq "cool new things"
          expect(mail_snippet.subject).to eq "a fancy custom subject"
          expect(mail_snippet.is_enabled).to be_falsey
        end
      end
    end
  end
end
