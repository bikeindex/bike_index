module TheftAlertPlanHelper
  def theft_alert_plan_title(plan)
    duration = [
      plan.duration_days,
      t(:days, scope: [:theft_alert_plans, :theft_alert_plan]).downcase,
    ].join(" ")

    "#{plan.name} (#{duration})"
  end
end
