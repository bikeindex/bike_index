module Organized
  class EmailsController < Organized::AdminController
    skip_before_action :ensure_admin!, only: [:show]
    before_action :ensure_member!, only: [:show]
    before_action :find_mail_snippets, only: [:show, :edit, :update]

    def index
    end

    def show
      # @email_preview and @organization are read by the email layout
      # (app/views/layouts/email.html.erb) and MailerHelper#render_supporters?
      @email_preview = true
      @organization = current_organization
      render OrganizedServices::EmailPreview.view_component(
        kind: @kind, organization: current_organization, user: current_user, params: params
      ), layout: "email"
    end

    def edit
      # Attempt to build an impound claim if it's an impound_claim kind - sometimes we can't
      # and we want to render that on the frontend
      if @impound_claim_kind
        @impound_claim = OrganizedServices::EmailPreview.find_or_build_impound_claim(
          kind: @kind, organization: @organization, params: params
        )
      end
    end

    def update
      if @object.update(permitted_parameters)
        flash[:success] = "Email updated"
        redirect_to edit_organization_email_path(@kind, organization_id: current_organization.to_param)
      else
        flash[:error] = "Unable to update your custom email - #{@object.errors.full_messages}"
        render :edit
      end
    end

    helper_method :viewable_email_kinds

    private

    def mail_snippets
      current_organization.mail_snippets.where(kind: MailSnippet.organization_message_kinds)
    end

    def viewable_email_kinds
      return @viewable_email_kinds if defined?(@viewable_email_kinds)

      email_kinds = ["finished_registration"]
      email_kinds += ["partial_registration"] if current_organization.enabled?("show_partial_registrations")
      email_kinds += ParkingNotification.kinds if current_organization.enabled?("parking_notifications")
      email_kinds += ["graduated_notification"] if current_organization.enabled?("graduated_notifications")
      email_kinds += ["organization_stolen_message"] if current_organization.enabled?("organization_stolen_message")
      email_kinds += %w[impound_claim_approved impound_claim_denied] if current_organization.enabled?("impound_bikes")
      @viewable_email_kinds = email_kinds
    end

    def find_mail_snippets
      @organization = current_organization
      @kind = if MailSnippet.organization_emails_with_snippets.include?(params[:id]) || params[:id] == "organization_stolen_message"
        params[:id]
      else
        viewable_email_kinds.first
      end
      # Allow superusers to view any email kind
      @kind = viewable_email_kinds.first unless viewable_email_kinds.include?(@kind) || current_user.superuser?
      @impound_claim_kind = @kind.match?(/impound_claim/)
      # These are uneditable kinds:
      @can_edit = !%w[finished_registration partial_registration].include?(@kind)
      return unless @can_edit

      if @kind == "organization_stolen_message"
        @object = OrganizationStolenMessage.for(current_organization)
      else
        @object = mail_snippets.where(kind: @kind).first
        @object ||= current_organization.mail_snippets.build(kind: @kind)
      end
    end

    def permitted_parameters
      if params[:organization_stolen_message].present?
        params.require(:organization_stolen_message).permit(:body, :is_enabled, :report_url)
      else
        params.require(:mail_snippet).permit(:body, :is_enabled, :subject)
      end
    end
  end
end
