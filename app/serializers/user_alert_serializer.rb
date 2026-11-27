# The web alert's copy as plain text, for clients that can't render the site's HTML and modals
class UserAlertSerializer < ApplicationSerializer
  attributes :id, :kind, :bike_id, :organization_id, :created_at

  # The copy follows the locale and the bike's title, neither of which moves the alert's version
  def perform_caching = false

  def created_at = object.created_at.to_i

  def attributes = super.merge(title: nil, message: nil, **content)

  private

  def content
    case object.kind
    when "phone_waiting_confirmation"
      {title: plain_text("components.shared_blocks.user_alerts.phone_waiting_confirmation.verify_number",
        phone_number: Phonifyer.display(object.alertable.phone)),
       action: plain_text("components.shared_blocks.user_alerts.phone_waiting_confirmation.confirm_your_phone_number"),
       url: edit_my_account_url}
    when "stolen_bike_without_location"
      {title: plain_text("components.shared_blocks.user_alerts.stolen_bike_without_location.stolen_missing_location_title"),
       message: plain_text("components.shared_blocks.user_alerts.stolen_bike_without_location.location_critical_html",
         bike_type: object.bike.type),
       action: plain_text("components.shared_blocks.user_alerts.stolen_bike_without_location.add_location_theft_bike_title_html",
         bike_title: object.bike.title_string),
       url: edit_bike_url(object.bike, edit_template: "theft_details", anchor: "where-theft-happened")}
    when "theft_alert_without_photo"
      {title: plain_text("components.shared_blocks.user_alerts.theft_alert_without_photo.missing_stolen_photo_title"),
       message: plain_text("components.shared_blocks.user_alerts.theft_alert_without_photo.photo_critical_html"),
       action: plain_text("components.shared_blocks.user_alerts.theft_alert_without_photo.add_photo_theft_bike_title_html",
         bike_title: object.bike.title_string),
       url: edit_bike_url(object.bike, edit_template: "photos")}
    when "unassigned_bike_org"
      {message: plain_text("components.pages.my_account.show.bike_alerts.connect_to_org",
        org_name: object.organization.short_name, bike_title: object.bike.title_string),
       action: plain_text("components.pages.my_account.show.bike_alerts.add_it_now"),
       url: my_account_url}
    when "unfinished_registration"
      action = plain_text("components.shared_blocks.user_alerts.unfinished_registration.finish_the_required_steps")
      {message: plain_text("components.shared_blocks.user_alerts.unfinished_registration.not_registered_yet_html",
        manufacturer: object.alertable.mnfg_name, cycle_type: object.alertable.type, finish_link: action),
       action:,
       url: register_url(b_param_token: object.alertable.id_token)}
    end
  end

  # How the components translate, so an _html key's interpolations are escaped and come
  # back out of the parse verbatim
  def plain_text(key, **)
    translated = ActiveSupport::HtmlSafeTranslation.translate(key, **)
    translated.html_safe? ? Nokogiri::HTML5.fragment(translated).text : translated
  end
end
