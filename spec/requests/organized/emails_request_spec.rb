require "rails_helper"

RSpec.describe Organized::EmailsController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/emails" }
  # we need a default organized bike to render emails, so build one
  let(:bike) { FactoryBot.create(:bike_organized, creation_organization: current_organization) }
  let(:all_viewable_email_kinds) do
    %w[finished_registration partial_registration appears_abandoned_notification parked_incorrectly_notification graduated_notification
      impound_notification impound_claim_approved impound_claim_denied organization_stolen_message]
  end
  let(:enabled_feature_slugs) { %w[show_partial_registrations parking_notifications graduated_notifications customize_emails impound_bikes organization_stolen_message] }

  context "logged_in_as_organization_user" do
    include_context :request_spec_logged_in_as_organization_user
    let(:current_organization) { FactoryBot.create(:organization_with_organization_features, :in_nyc, enabled_feature_slugs: enabled_feature_slugs) }
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
          expect(assigns(:email_preview)).to be_truthy
          expect(response.body).to_not match(parking_notification.retrieval_link_token)
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
    let(:current_organization) { FactoryBot.create(:organization_with_organization_features, :in_nyc, enabled_feature_slugs: enabled_feature_slugs) }
    describe "index" do
      it "renders" do
        get base_url
        expect(response).to render_template(:index)
        # Sanity check
        expect(all_viewable_email_kinds).to match_array(MailSnippet.organization_message_kinds + %w[finished_registration partial_registration organization_stolen_message])
        expect(assigns(:viewable_email_kinds)).to match_array(all_viewable_email_kinds)
      end
    end

    describe "show" do
      context "appears_abandoned_notification" do
        it "renders" do
          expect(bike).to be_present
          expect(current_organization.parking_notifications.appears_abandoned_notification.count).to eq 0
          expect(current_organization.bikes.pluck(:id)).to eq([bike.id])
          get "#{base_url}/appears_abandoned_notification"
          expect(response.status).to eq(200)
          expect(response).to render_template("organized_mailer/parking_notification")
          expect(assigns(:parking_notification).is_a?(ParkingNotification)).to be_truthy
          expect(assigns(:parking_notification).retrieval_link_token).to be_blank
          expect(assigns(:email_preview)).to be_truthy
          expect(assigns(:kind)).to eq "appears_abandoned_notification"
          current_organization.reload
          expect(current_organization.parking_notifications.appears_abandoned_notification.count).to eq 0
        end
      end
      context "passed id" do
        let!(:parking_notification) { FactoryBot.create(:parking_notification, organization: current_organization, kind: "parked_incorrectly_notification") }
        it "renders passed id" do
          get "#{base_url}/parked_incorrectly_notification", params: {parking_notification_id: parking_notification.id}
          expect(response.status).to eq(200)
          expect(response).to render_template("organized_mailer/parking_notification")
          expect(assigns(:parking_notification)).to eq parking_notification
          expect(assigns(:email_preview)).to be_truthy
          expect(assigns(:kind)).to eq "parked_incorrectly_notification"
          expect(response.body).to_not match(parking_notification.retrieval_link_token)
        end
        context "different org" do
          let!(:parking_notification) { FactoryBot.create(:parking_notification) }
          it "404s" do
            get "#{base_url}/appears_abandoned_notification", params: {parking_notification_id: parking_notification.id}
            expect(response.status).to eq 404
          end
        end
      end
      context "no bikes" do
        it "renders" do
          expect(current_organization.parking_notifications.appears_abandoned_notification.count).to eq 0
          expect(current_organization.bikes.pluck(:id)).to eq([])
          get "#{base_url}/appears_abandoned_notification"
          expect(response.status).to eq(200)
          expect(response).to render_template("organized_mailer/parking_notification")
          expect(assigns(:parking_notification).is_a?(ParkingNotification)).to be_truthy
          expect(assigns(:parking_notification).retrieval_link_token).to be_blank
          expect(assigns(:email_preview)).to be_truthy
          expect(assigns(:kind)).to eq "appears_abandoned_notification"
          current_organization.reload
          expect(current_organization.parking_notifications.appears_abandoned_notification.count).to eq 0
        end
      end
      context "graduated_notification passed id" do
        let!(:graduated_notification) { FactoryBot.create(:graduated_notification, organization: current_organization) }
        it "renders" do
          get "#{base_url}/graduated_notification", params: {graduated_notification_id: graduated_notification.id}
          expect(response.status).to eq(200)
          expect(response).to render_template("organized_mailer/graduated_notification")
          expect(assigns(:graduated_notification).id).to eq graduated_notification.id
          expect(assigns(:email_preview)).to be_truthy
          expect(response.body).to_not match(graduated_notification.marked_remaining_link_token)
          expect(assigns(:kind)).to eq "graduated_notification"
        end
        context "different org" do
          let!(:graduated_notification) { FactoryBot.create(:graduated_notification) }
          it "404s" do
            get "#{base_url}/graduated_notification", params: {graduated_notification_id: graduated_notification.id}
            expect(response.status).to eq 404
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
      context "organization_stolen_message" do
        let(:enabled_feature_slugs) { %w[customize_emails organization_stolen_message] }
        let(:organization_stolen_message) { OrganizationStolenMessage.for(current_organization) }
        it "renders" do
          expect(organization_stolen_message.id).to be_present
          expect(organization_stolen_message.body).to be_blank
          get "#{base_url}/organization_stolen_message"
          expect(response.status).to eq(200)
          expect(response).to render_template("organized_mailer/finished_registration")
          expect(assigns(:viewable_email_kinds)).to match_array(%w[finished_registration organization_stolen_message])
          expect(assigns(:bike).id).to eq 42
          expect(assigns(:bike).current_stolen_record).to be_present
          # Because the stolen_message is blank
          expect(assigns(:bike).current_stolen_record.organization_stolen_message_id).to be_blank
        end
        context "with a stolen bike" do
          let!(:stolen_record) { FactoryBot.create(:stolen_record, bike: bike) }
          it "renders that bike" do
            organization_stolen_message.update(body: "something here", is_enabled: true)
            expect(bike.reload.status).to eq "status_stolen"
            expect(bike.current_ownership.token).to be_present
            expect(current_organization.bikes.pluck(:id)).to eq([bike.id])
            get "#{base_url}/organization_stolen_message"
            expect(response.status).to eq(200)
            expect(response).to render_template("organized_mailer/finished_registration")
            expect(assigns(:viewable_email_kinds)).to match_array(%w[finished_registration organization_stolen_message])
            expect(assigns(:bike).id).to eq bike.id
            expect(assigns(:bike).current_stolen_record).to be_present
            expect(assigns(:bike).current_stolen_record.organization_stolen_message_id).to eq organization_stolen_message.id
            expect(response.body).to_not match(bike.current_ownership.token)
          end
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
      context "partial_registration without access" do
        let(:enabled_feature_slugs) { %w[customize_emails graduated_notifications] }
        it "redirects" do
          get "#{base_url}/partial_registration/edit"
          expect(response.status).to eq(200)
          expect(response).to render_template(:edit)
          expect(assigns(:kind)).to eq "finished_registration"
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
            is_enabled: "true"
          }
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
              is_enabled: "0"
            }
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

  context "logged_in_as_superuser" do
    include_context :request_spec_logged_in_as_superuser
    let(:current_organization) { FactoryBot.create(:organization_with_organization_features, :in_nyc, enabled_feature_slugs: enabled_feature_slugs, kind: "bike_shop") }
    # Also defined in controller
    let(:viewable_kinds) { ParkingNotification.kinds + %w[finished_registration partial_registration graduated_notification impound_claim_approved impound_claim_denied organization_stolen_message] }
    describe "edit" do
      it "renders" do
        viewable_kinds.each do |kind|
          get "#{base_url}/#{kind}/edit"
          expect(response.status).to eq(200)
          expect(response).to render_template(:edit)
          expect(assigns(:kind)).to eq kind
          unless %w[partial_registration finished_registration].include?(kind)
            expect(assigns(:can_edit)).to be_truthy
          end
        end
      end
      context "partial_registration without access" do
        let(:enabled_feature_slugs) { %w[customize_emails graduated_notifications] }
        it "redirects" do
          get "#{base_url}/partial_registration/edit"
          expect(response.status).to eq(200)
          expect(response).to render_template(:edit)
          expect(assigns(:kind)).to eq "partial_registration"
        end
      end
    end
    describe "update" do
      context "organization_stolen_message" do
        let(:organization_stolen_message) { OrganizationStolenMessage.for(current_organization) }
        let(:update_params) do
          {
            organization_stolen_message: {
              id: organization_stolen_message.id,
              body: "text for stolen message",
              organization_id: 844,
              is_enabled: true,
              report_url: "something.com/stuff=true?utm=fffff"
            }
          }
        end
        it "updates" do
          expect(current_organization.kind).to eq "bike_shop"
          # exists because UpdateOrganizationAssociationsWorker, destroy to test a weird state
          expect(organization_stolen_message).to be_present
          get "#{base_url}/organization_stolen_message/edit"
          expect(response.status).to eq(200)
          expect(response).to render_template(:edit)
          expect(organization_stolen_message.kind).to eq "association"
          expect(organization_stolen_message.body).to be_blank
          expect(organization_stolen_message.is_enabled).to be_falsey
          expect {
            put "#{base_url}/organization_stolen_message", params: update_params
          }.to change(MailSnippet, :count).by 0
          organization_stolen_message.reload
          expect(organization_stolen_message.body).to eq "text for stolen message"
          expect(organization_stolen_message.organization_id).to eq current_organization.id
          expect(organization_stolen_message.is_enabled).to be_truthy
          expect(organization_stolen_message.report_url).to eq "http://something.com/stuff=true?utm=fffff"
        end
      end
    end
  end
end
