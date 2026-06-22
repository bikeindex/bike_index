require "rails_helper"

RSpec.describe Organized::EmailsController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/emails" }
  # we need a default organized bike to render emails, so build one
  let(:bike) { FactoryBot.create(:bike_organized, creation_organization: current_organization) }
  let(:all_viewable_email_kinds) do
    %w[finished_registration partial_registration appears_abandoned_notification parked_incorrectly_notification graduated_notification
      other_parking_notification impound_notification impound_claim_approved impound_claim_denied organization_stolen_message]
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
          components = rendered_view_component_names { get "#{base_url}/appears_abandoned_notification" }
          expect(response.status).to eq(200)
          expect(components).to include("Emails::ParkingNotification::Component")
          expect(response.body).to include(OrganizedServices::EmailPreview::TOKEN_PATH)
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
        let!(:header_snippet) { FactoryBot.create(:mail_snippet, kind: "header", organization: current_organization, body: "<p>HEADER SNIPPET</p>", is_enabled: true) }
        it "renders" do
          expect(bike).to be_present
          expect(current_organization.parking_notifications.appears_abandoned_notification.count).to eq 0
          expect(current_organization.bikes.pluck(:id)).to eq([bike.id])
          components = rendered_view_component_names { get "#{base_url}/appears_abandoned_notification" }
          expect(response.status).to eq(200)
          expect(components).to include("Emails::ParkingNotification::Component")
          expect(response.body).to include(OrganizedServices::EmailPreview::TOKEN_PATH)
          # Layout/helper hooks: @email_preview enables the preview-only CSS and suppresses
          # the supporters block; @organization makes the layout render org snippets even
          # though controller_path is "organized/emails", not "organized_mailer".
          expect(response.body).to include("html { background: #e6e6e6;")
          expect(response.body).to_not include("Bike Index is also supported by")
          expect(response.body).to include("HEADER SNIPPET")
          expect(assigns(:kind)).to eq "appears_abandoned_notification"
          current_organization.reload
          expect(current_organization.parking_notifications.appears_abandoned_notification.count).to eq 0
        end
      end
      context "passed id" do
        let!(:parking_notification) { FactoryBot.create(:parking_notification, organization: current_organization, kind: "parked_incorrectly_notification") }
        it "renders passed id" do
          components = rendered_view_component_names do
            get "#{base_url}/parked_incorrectly_notification", params: {parking_notification_id: parking_notification.id}
          end
          expect(response.status).to eq(200)
          expect(components).to include("Emails::ParkingNotification::Component")
          expect(response.body).to include(OrganizedServices::EmailPreview::TOKEN_PATH)
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
        context "with mail_snippet changes after the notification was sent" do
          include_context :with_paper_trail

          let!(:mail_snippet) do
            FactoryBot.create(:mail_snippet,
              kind: "parked_incorrectly_notification",
              organization: current_organization,
              is_enabled: true,
              body: "snippet body when sent")
          end
          let!(:header_snippet) do
            FactoryBot.create(:mail_snippet,
              kind: "header",
              organization: current_organization,
              is_enabled: true,
              body: "header when sent")
          end
          let!(:sent_parking_notification) do
            pn = FactoryBot.create(:parking_notification,
              organization: current_organization,
              kind: "parked_incorrectly_notification",
              created_at: 1.hour.ago)
            FactoryBot.create(:notification, kind: "parking_notification", notifiable: pn, delivery_status: "delivery_success", bike: pn.bike, message_channel_target: pn.email)
            pn
          end
          let!(:unsent_parking_notification) do
            FactoryBot.create(:parking_notification,
              organization: current_organization,
              kind: "parked_incorrectly_notification")
          end

          before do
            mail_snippet.versions.first.update_columns(created_at: 2.hours.ago)
            mail_snippet.update!(body: "snippet body now")
            header_snippet.versions.first.update_columns(created_at: 2.hours.ago)
            header_snippet.destroy!
          end

          it "renders snippets as they were at sent time (including destroyed ones), and current snippets for unsent notifications" do
            expect(sent_parking_notification.sent_at).to be_present
            expect(unsent_parking_notification.sent_at).to be_nil
            expect(mail_snippet.reload.body).to eq "snippet body now"
            expect(MailSnippet.where(kind: "header", organization: current_organization)).to be_empty

            get "#{base_url}/parked_incorrectly_notification", params: {parking_notification_id: sent_parking_notification.id, versioned: true}
            expect(response.status).to eq(200)
            expect(response.body).to include("snippet body when sent")
            expect(response.body).to include("header when sent")
            expect(response.body).to_not include("snippet body now")

            get "#{base_url}/parked_incorrectly_notification", params: {parking_notification_id: unsent_parking_notification.id, versioned: true}
            expect(response.status).to eq(200)
            expect(response.body).to include("snippet body now")
            expect(response.body).to_not include("snippet body when sent")
            expect(response.body).to_not include("header when sent")
          end
        end
      end
      context "no bikes" do
        it "renders" do
          expect(current_organization.parking_notifications.appears_abandoned_notification.count).to eq 0
          expect(current_organization.bikes.pluck(:id)).to eq([])
          components = rendered_view_component_names { get "#{base_url}/appears_abandoned_notification" }
          expect(response.status).to eq(200)
          expect(components).to include("Emails::ParkingNotification::Component")
          expect(response.body).to include(OrganizedServices::EmailPreview::TOKEN_PATH)
          expect(assigns(:kind)).to eq "appears_abandoned_notification"
          current_organization.reload
          expect(current_organization.parking_notifications.appears_abandoned_notification.count).to eq 0
        end
      end
      context "graduated_notification passed id" do
        let!(:graduated_notification) { FactoryBot.create(:graduated_notification, organization: current_organization) }
        it "renders" do
          components = rendered_view_component_names do
            get "#{base_url}/graduated_notification", params: {graduated_notification_id: graduated_notification.id}
          end
          expect(response.status).to eq(200)
          expect(components).to include("Emails::GraduatedNotification::Component")
          expect(response.body).to include(OrganizedServices::EmailPreview::TOKEN_PATH)
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
          components = rendered_view_component_names { get "#{base_url}/finished_registration" }
          expect(response.status).to eq(200)
          expect(components).to include("Emails::FinishedRegistration::Component")
          expect(response.body).to include("Bike details")
          expect(response.body).to include("Protect your bike by following these locking guidelines")
          expect(response.body).to include(OrganizedServices::EmailPreview::TOKEN_PATH)
          expect(assigns(:viewable_email_kinds)).to eq(["finished_registration"])
          # And it defaults to finished registration, if unable to parse kind
          components = rendered_view_component_names { get "#{base_url}/whateverrrrr" }
          expect(response.status).to eq(200)
          expect(components).to include("Emails::FinishedRegistration::Component")
          expect(response.body).to include("Bike details")
          expect(response.body).to include("Protect your bike by following these locking guidelines")
          expect(response.body).to include(OrganizedServices::EmailPreview::TOKEN_PATH)
          expect(assigns(:viewable_email_kinds)).to eq(["finished_registration"])
        end

        context "with mail_snippet changes after the ownership was created" do
          include_context :with_paper_trail

          let!(:welcome_snippet) do
            FactoryBot.create(:mail_snippet, kind: "welcome", organization: current_organization,
              is_enabled: true, body: "welcome when sent")
          end
          let!(:after_welcome_snippet) do
            FactoryBot.create(:mail_snippet, kind: "after_welcome", organization: current_organization,
              is_enabled: true, body: "after_welcome when sent")
          end
          let!(:security_snippet) do
            FactoryBot.create(:mail_snippet, kind: "security", organization: current_organization,
              is_enabled: true, body: "security when sent")
          end

          before do
            bike.current_ownership.update_columns(created_at: 1.hour.ago)
            [welcome_snippet, after_welcome_snippet, security_snippet].each do |snippet|
              snippet.versions.first.update_columns(created_at: 2.hours.ago)
              snippet.update!(body: "#{snippet.kind} now")
            end
          end

          it "renders snippets as they were at ownership.created_at" do
            get "#{base_url}/finished_registration"
            expect(response.status).to eq(200)
            expect(response.body).to include("welcome when sent")
            expect(response.body).to include("after_welcome when sent")
            expect(response.body).to include("security when sent")
            expect(response.body).to_not include("welcome now")
            expect(response.body).to_not include("after_welcome now")
            expect(response.body).to_not include("security now")
          end
        end
      end
      context "partial_registration" do
        let(:enabled_feature_slugs) { %w[customize_emails show_partial_registrations graduated_notifications] }
        it "renders" do
          components = rendered_view_component_names { get "#{base_url}/partial_registration" }
          expect(response.status).to eq(200)
          expect(components).to include("Emails::PartialRegistration::Component")
          expect(response.body).to include(OrganizedServices::EmailPreview::TOKEN_PATH)
          expect(assigns(:viewable_email_kinds)).to match_array(%w[finished_registration partial_registration graduated_notification])
        end
      end
      context "organization_stolen_message" do
        let(:enabled_feature_slugs) { %w[customize_emails organization_stolen_message] }
        let(:organization_stolen_message) { OrganizationStolenMessage.for(current_organization) }
        it "renders" do
          expect(organization_stolen_message.id).to be_present
          expect(organization_stolen_message.body).to be_blank
          components = rendered_view_component_names { get "#{base_url}/organization_stolen_message" }
          expect(response.status).to eq(200)
          expect(components).to include("Emails::FinishedRegistration::Component")
          # Fake bike doesn't have status_stolen, so it renders the normal registration message
          expect(response.body).to include("Protect your bike by following these locking guidelines")
          expect(response.body).to include(OrganizedServices::EmailPreview::TOKEN_PATH)
          expect(assigns(:viewable_email_kinds)).to match_array(%w[finished_registration organization_stolen_message])
        end
        context "with a stolen bike" do
          let!(:stolen_record) { FactoryBot.create(:stolen_record, bike: bike) }
          it "renders that bike" do
            organization_stolen_message.update(body: "something here", is_enabled: true)
            stolen_record.update(organization_stolen_message: organization_stolen_message)
            expect(bike.reload.status).to eq "status_stolen"
            expect(bike.current_ownership.token).to be_present
            expect(current_organization.bikes.pluck(:id)).to eq([bike.id])
            components = rendered_view_component_names { get "#{base_url}/organization_stolen_message" }
            expect(response.status).to eq(200)
            expect(components).to include("Emails::FinishedRegistration::Component")
            # When claim_message is present, it renders the claim_message partial
            expect(response.body).to include("something here") # organization_stolen_message body
            expect(response.body).to include("registered your bike on Bike Index")
            # Stolen-specific text rendered by the FinishedRegistration component
            expect(response.body).to include("Mark your bike recovered")
            expect(response.body).to include("Hopefully you find the")
            # Confirms the bike rendered is the real stolen bike
            expect(response.body).to include(bike.serial_display)
            expect(bike.reload.current_stolen_record).to be_present
            expect(bike.current_stolen_record.organization_stolen_message_id).to eq organization_stolen_message.id
            expect(assigns(:viewable_email_kinds)).to match_array(%w[finished_registration organization_stolen_message])
            expect(response.body).to include(OrganizedServices::EmailPreview::TOKEN_PATH)
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
      include_context :with_paper_trail

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
        version = mail_snippet.versions.last
        expect(version.event).to eq "create"
        expect(version.whodunnit).to eq current_user.id.to_s
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
          version = mail_snippet.versions.last
          expect(version.event).to eq "update"
          expect(version.whodunnit).to eq current_user.id.to_s
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
          # exists because UpdateOrganizationAssociationsJob, destroy to test a weird state
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
