module Organized
  class EmailsController < Organized::AdminController
    skip_before_action :ensure_admin!, only: [:show]
    before_action :ensure_member!, only: [:show]
    before_action :find_mail_snippets, only: [:show, :edit, :update]

    def index
    end

    def show
      @organization = current_organization
      @email_preview = true
      if ParkingNotification.kinds.include?(@kind)
        find_or_build_parking_notification
        render template: "/organized_mailer/parking_notification", layout: "email"
      elsif @kind == "graduated_notification"
        find_or_build_graduated_notification
        render template: "/organized_mailer/graduated_notification", layout: "email"
      elsif @kind == "partial_registration"
        build_partial_email
        render template: "/organized_mailer/partial_registration", layout: "email"
      else # Default to finished email
        build_finished_email
        render template: "/organized_mailer/finished_registration", layout: "email"
      end
    end

    def edit
      @can_edit = !%w[finished_registration partial_registration].include?(@kind)
    end

    def update
      if @mail_snippet.update(permitted_parameters)
        flash[:success] = "Email updated"
        redirect_to edit_organization_email_path(@kind, organization_id: current_organization.to_param)
      else
        flash[:error] = "Unable to update your custom email - #{@mail_snippet.errors.full_messages}"
        render :edit
      end
    end

    helper_method :viewable_email_kinds

    private

    def parking_notifications
      current_organization.parking_notifications
    end

    def mail_snippets
      current_organization.mail_snippets.where(kind: MailSnippet.organization_message_kinds)
    end

    def viewable_email_kinds
      return @viewable_email_kinds if defined?(@viewable_email_kinds)
      viewable_email_kinds = ["finished_registration"]
      viewable_email_kinds += ["partial_registration"] if current_organization.enabled?("show_partial_registrations")
      viewable_email_kinds += ParkingNotification.kinds if current_organization.enabled?("parking_notifications")
      viewable_email_kinds += ["graduated_notification"] if current_organization.enabled?("graduated_notifications")
      @viewable_email_kinds = viewable_email_kinds
    end

    def find_mail_snippets
      @kind = viewable_email_kinds.include?(params[:id]) ? params[:id] : viewable_email_kinds.first
      if ParkingNotification.kinds.include?(@kind) || @kind == "graduated_notification"
        @mail_snippet = mail_snippets.where(kind: @kind).first
        @mail_snippet ||= current_organization.mail_snippets.build(kind: @kind)
      end
    end

    def permitted_mail_snippet_kinds
      MailSnippet.organization_message_kinds
    end

    def permitted_parameters
      params.require(:mail_snippet).permit(:body, :is_enabled, :subject)
    end

    def build_partial_email
      @b_param = @organization.b_params.order(:created_at).last
      @b_param ||= BParam.new(organization_id: @organization.id)
    end

    def build_finished_email
      @bike = @organization.bikes.last
      @ownership = @bike.current_ownership
      @user = @ownership.owner
      @vars = {
        new_bike: (@bike.ownerships.count == 1),
        email: @ownership.owner_email,
        new_user: User.fuzzy_email_find(@ownership.owner_email).present?,
        registered_by_owner: (@ownership.user.present? && @bike.creator_id == @ownership.user_id)
      }
    end

    def find_or_build_graduated_notification
      graduated_notifications = @organization.graduated_notifications
      @graduated_notification = graduated_notifications.find(params[:graduated_notification_id]) if params[:graduated_notification_id].present?
      @graduated_notification ||= graduated_notifications.last
      @graduated_notification ||= GraduatedNotification.new(organization_id: current_organization.id, bike: current_organization.bikes.last)
      @bike = @graduated_notification.bike
      @retrieval_link_url = "#"
      @bike ||= current_organization.bikes.last
      @graduated_notification
    end

    def find_or_build_parking_notification
      parking_notifications = current_organization.parking_notifications
      @parking_notification = parking_notifications.find(params[:parking_notification_id]) if params[:parking_notification_id].present?
      @parking_notification ||= parking_notifications.where(kind: @kind).last
      unless @parking_notification.present?
        @parking_notification = parking_notifications.build(bike: current_organization.bikes.last,
                                                            kind: @kind,
                                                            user: current_user,
                                                            created_at: Time.current - 1.hour)
        @parking_notification.set_location_from_organization
      end
      @bike = @parking_notification.bike
      @retrieval_link_url = "#"
      @parking_notification
    end
  end
end
