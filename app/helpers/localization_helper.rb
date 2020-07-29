module LocalizationHelper
  def theft_alert_plan_title(plan)
    duration = [
      plan.duration_days,
      t(:days, scope: [:theft_alert_plans, :theft_alert_plan]).downcase
    ].join(" ")

    "#{plan.name} (#{duration})"
  end

  # Language choices available for request locale and localized models (Blog,
  # TheftAlertPlan).
  #
  # Return an array of tuples, each with the following strings:
  #
  # [<localized language name>, <language key (from Blog::LANGUAGE_ENUM)>]
  def language_choices
    @language_choices ||=
      I18n
        .available_locales
        .map { |locale| [t(locale, scope: [:locales]), locale.to_s] }
        .sort_by { |language_name, _| language_name.downcase }
  end
end
