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
      find_or_build_email
      if @kind == "graduated_notification"
        render template: "/organized_mailer/graduated_notification", layout: "email"
      else
        render template: "/organized_mailer/parking_notification", layout: "email"
      end
    end

    def edit
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
      ParkingNotification.kinds + ["graduated_notification"]
    end

    def find_mail_snippets
      @kind = MailSnippet.organization_message_kinds.include?(params[:id]) ? params[:id] : MailSnippet.organization_message_kinds.first
      @mail_snippet = mail_snippets.where(kind: @kind).first
      @mail_snippet ||= current_organization.mail_snippets.build(kind: @kind)
    end

    def find_or_build_email
      @organization = current_organization
      @email_preview = true
      if @kind == ""
      elsif @kind == "graduated_notification"
        graduated_notifications = current_organization.graduated_notifications
        @graduated_notification = graduated_notifications.find(params[:graduated_notification_id]) if params[:graduated_notification_id].present?
        @graduated_notification ||= graduated_notifications.last
        @graduated_notification ||= GraduatedNotification.new(organization_id: current_organization.id, bike: current_organization.bikes.last)
        @bike = @graduated_notification.bike
        @bikes = @graduated_notification.associated_bikes
        @retrieval_link_url = "#"
        @bike ||= current_organization.bikes.last
      else
        parking_notifications = current_organization.parking_notifications
        @parking_notification = parking_notifications.find(params[:parking_notification_id]) if params[:parking_notification_id].present?
        @parking_notification ||= parking_notifications.where(kind: @kind).last
        @parking_notification ||= build_parking_notification
        @bike = @parking_notification.bike
        @retrieval_link_url = "#"
      end
    end

    def permitted_mail_snippet_kinds
      MailSnippet.organization_message_kinds
    end

    def permitted_parameters
      params.require(:mail_snippet).permit(:body, :is_enabled)
    end

    def build_parking_notification
      parking_notification = parking_notifications.build(bike: current_organization.bikes.last,
                                                         kind: @kind,
                                                         user: current_user,
                                                         created_at: Time.current - 1.hour)
      parking_notification.set_location_from_organization
      parking_notification
    end
  end
end
