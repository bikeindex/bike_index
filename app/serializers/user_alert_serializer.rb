# Plain text and the web URL that resolves the alert, for clients that can't render the
# site's HTML and modals
class UserAlertSerializer < ApplicationSerializer
  attributes :id, :kind, :bike_id, :organization_id, :created_at

  # The copy follows the locale and the bike's title, neither of which moves the alert's version
  def perform_caching = false

  def created_at = object.created_at.to_i

  def attributes = super.merge(content)

  private

  def content
    case object.kind
    when "phone_waiting_confirmation"
      {title: I18n.t("shared.user_alerts.phone_waiting_confirmation_title"),
       message: I18n.t("shared.user_alerts.phone_waiting_confirmation_message",
         phone_number: Phonifyer.display(object.alertable.phone)),
       url: edit_my_account_url}
    when "stolen_bike_without_location"
      {title: I18n.t("shared.user_alerts.stolen_bike_without_location_title"),
       message: I18n.t("shared.user_alerts.stolen_bike_without_location_message",
         bike_title: object.bike.title_string),
       url: edit_bike_url(object.bike, edit_template: "theft_details", anchor: "where-theft-happened")}
    when "theft_alert_without_photo"
      {title: I18n.t("shared.user_alerts.theft_alert_without_photo_title"),
       message: I18n.t("shared.user_alerts.theft_alert_without_photo_message",
         bike_title: object.bike.title_string),
       url: edit_bike_url(object.bike, edit_template: "photos")}
    when "unassigned_bike_org"
      org_name = object.organization.short_name
      {title: I18n.t("shared.user_alerts.unassigned_bike_org_title", org_name:),
       message: I18n.t("shared.user_alerts.unassigned_bike_org_message", org_name:,
         bike_title: object.bike.title_string),
       url: my_account_url}
    when "unfinished_registration"
      {title: I18n.t("shared.user_alerts.unfinished_registration_title"),
       message: I18n.t("shared.user_alerts.unfinished_registration_message",
         manufacturer: object.alertable.mnfg_name, bike_type: object.alertable.type),
       url: register_url(b_param_token: object.alertable.id_token)}
    end
  end
end
