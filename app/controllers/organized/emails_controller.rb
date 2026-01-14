module Organized
  class EmailsController < Organized::AdminController
    skip_before_action :ensure_admin!, only: [:show]
    before_action :ensure_member!, only: [:show]
    before_action :find_mail_snippets, only: [:show, :edit, :update]

    def index
    end

    def show
      @email_preview = true
      # NOTE: This is a bad hack, but there isn't a good place to define this
      @email_preview_tokenized_url = "/404"
      if ParkingNotification.kinds.include?(@kind)
        find_or_build_parking_notification
        render template: "/organized_mailer/parking_notification", layout: "email"
      elsif @kind == "graduated_notification"
        find_or_build_graduated_notification
        render template: "/organized_mailer/graduated_notification", layout: "email"
      elsif %w[impound_claim_approved impound_claim_denied].include?(@kind)
        find_or_build_impound_claim(@kind)
        render template: "/organized_mailer/impound_claim_approved_or_denied", layout: "email"
      elsif @kind == "partial_registration"
        build_partial_email
        render template: "/organized_mailer/partial_registration", layout: "email"
      else # Default to finished email
        build_finished_email
        render Emails::FinishedRegistration::Component.new(
          ownership: @ownership,
          bike: @bike,
          email_preview: true,
          email_preview_tokenized_url: @email_preview_tokenized_url
        ), layout: "email"
      end
    end

    def edit
      # Attempt to build an impound claim if it's an impound_claim kind - sometimes we can't
      # and we want to render that on the frontend
      find_or_build_impound_claim(@kind) if @impound_claim_kind
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

    def parking_notifications
      current_organization.parking_notifications
    end

    # What if they don't have any bikes! return something
    def default_bike
      bike = current_organization.bikes.last
      return bike if bike.present?

      bike = Bike.new(id: 42,
        creation_organization: current_organization,
        owner_email: current_user.email,
        creator: current_user,
        manufacturer: Manufacturer.other,
        frame_model: "Example bike",
        primary_frame_color: Color.black)
      @ownership = bike.ownerships.build(owner_email: bike.owner_email, creator: current_user, id: 420)
      bike.current_ownership = @ownership
      bike
    end

    def default_stolen_bike
      bike = current_organization.bikes.status_stolen.last
      if bike.blank?
        bike = default_bike
        bike.current_stolen_record = StolenRecord.new(date_stolen: Time.current - 1.day)
      end
      if OrganizationStolenMessage.for(current_organization).is_enabled
        bike.current_stolen_record.organization_stolen_message = OrganizationStolenMessage.for(current_organization)
      end
      bike
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

    def build_partial_email
      @b_param = @organization.b_params.order(:created_at).last
      @b_param ||= BParam.new(organization_id: @organization.id)
    end

    def build_finished_email
      @bike = (@kind == "organization_stolen_message") ? default_stolen_bike : default_bike
      @ownership ||= @bike.current_ownership # Gross things to make default_bike work
    end

    def find_or_build_graduated_notification
      graduated_notifications = @organization.graduated_notifications
      @graduated_notification = graduated_notifications.find(params[:graduated_notification_id]) if params[:graduated_notification_id].present?
      @graduated_notification ||= graduated_notifications.last
      @graduated_notification ||= GraduatedNotification.new(organization_id: current_organization.id, bike: default_bike)
      @bike = @graduated_notification.bike || default_bike
      @graduated_notification
    end

    def find_or_build_impound_claim(kind)
      status = (@kind == "impound_claim_approved") ? "approved" : "denied"
      impound_claims = @organization.impound_claims
      @impound_claim = impound_claims.find(params[:impound_claim_id]) if params[:impound_claim_id].present?
      @impound_claim ||= impound_claims.where(status: status).last
      return @impound_claim if @impound_claim.present?

      impound_record = current_organization.impound_records.last
      # Just can't make it happen, so skip preview
      if impound_record.present?
        @impound_claim = impound_record.impound_claims.build(status: status)
      end
    end

    def find_or_build_parking_notification
      parking_notifications = current_organization.parking_notifications
      @parking_notification = parking_notifications.find(params[:parking_notification_id]) if params[:parking_notification_id].present?
      @parking_notification ||= parking_notifications.where(kind: @kind).last
      unless @parking_notification.present?
        @parking_notification = parking_notifications.build(bike: default_bike,
          kind: @kind,
          user: current_user,
          created_at: Time.current - 1.hour)
        @parking_notification.set_location_from_organization
      end
      @bike = @parking_notification.bike || default_bike
      @parking_notification
    end
  end
end
