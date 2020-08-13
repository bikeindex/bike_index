module AdminHelper
  def dev_nav_select_links
    return [] unless current_user&.developer?
    [
      {title: "Mail Snippets", path: admin_mail_snippets_path, match_controller: true}
    ]
  end

  def admin_nav_select_links
    [
      {title: "Users", path: admin_users_path, match_controller: true},
      {title: "Bikes", path: admin_bikes_path, match_controller: true},
      {title: "Stolen Bikes", path: admin_stolen_bikes_path, match_controller: true},
      {title: "Stolen Notifications", path: admin_stolen_notifications_url, match_controller: true},
      {title: "External Registry Bikes", path: admin_external_registry_bikes_path, match_controller: true},
      {title: "External Registry Credentials", path: admin_external_registry_credentials_path, match_controller: true},
      {title: "Organizations", path: admin_organizations_path, match_controller: true},
      {title: "News", path: admin_news_index_path, match_controller: true},
      {title: "POS Integration", path: lightspeed_interface_path, match_controller: false},
      {title: "Ambassador Activities", path: admin_ambassador_tasks_path, match_controller: true},
      {title: "Completed Ambassador Activities", path: admin_ambassador_task_assignments_path, match_controller: true},
      {title: "Promoted Alerts", path: admin_theft_alerts_path, match_controller: true},
      {title: "Promoted Alert Plans", path: admin_theft_alert_plans_path, match_controller: true},
      {title: "Payments", path: admin_payments_path, match_controller: true},
      {title: "Paid Features", path: admin_organization_features_path, match_controller: true},
      {title: "Invoices", path: admin_invoices_path(query: "active", direction: "asc", sort: "subscription_end_at"), match_controller: true},
      {title: "Impound Records", path: admin_impound_records_path, match_controller: true},
      {title: "Parking Notifications", path: admin_parking_notifications_path, match_controller: true},
      {title: "Recoveries", path: admin_recoveries_path, match_controller: true},
      {title: "Recovery Displays", path: admin_recovery_displays_path, match_controller: true},
      {title: "Memberships", path: admin_memberships_path, match_controller: true},
      {title: "Manufacturers", path: admin_manufacturers_path, match_controller: true},
      {title: "TSV Exports", path: admin_tsvs_path, match_controller: false},
      {title: "Credibility badges", path: admin_credibility_badges_path, match_controller: false},
      {title: "Maintenance", path: admin_maintenance_path, match_controller: false},
      {title: "Failed Bikes", path: admin_failed_bikes_path, match_controller: true},
      {title: "Component Types", path: admin_ctypes_path, match_controller: true},
      {title: "Graphs", path: admin_graphs_path, match_controller: true},
      {title: "Paints", path: admin_paints_path, match_controller: true},
      {title: "Feedback & Messages", path: admin_feedbacks_path, match_controller: true},
      {title: "Twitter Accounts", path: admin_twitter_accounts_path, match_controller: true},
      {title: "Tweets", path: admin_tweets_path, match_controller: true},
      {title: "Stickers", path: admin_bike_stickers_path, match_controller: true},
      {title: "Sticker Updates", path: admin_bike_sticker_updates_path, match_controller: true},
      {title: "Exports", path: admin_exports_path, match_controller: true},
      {title: "Bulk Imports", path: admin_bulk_imports_path, match_controller: true},
      {title: "Partial Bikes", path: admin_partial_bikes_path, match_controller: true},
      {title: "Duplicate Bikes", path: duplicates_admin_bikes_path, match_controller: false},
      {title: "Feature Flags", path: admin_feature_flags_path, match_controller: false},
      {title: "Scheduled Jobs", path: admin_scheduled_jobs_path, match_controller: false},
      {title: "Exchange Rates", path: admin_exchange_rates_path, match_controller: false},
      {title: "Exit Admin", path: root_path, match_controller: false}
    ] + dev_nav_select_links
  end

  def admin_nav_select_link_active
    return @admin_nav_select_link_active if defined?(@admin_nav_select_link_active)
    @admin_nav_select_link_active = admin_nav_select_links.detect { |link| current_page_active?(link[:path], link[:match_controller]) }
    unless @admin_nav_select_link_active.present?
      # Because organization invoices edit doesn't match controller
      @admin_nav_select_link_active = admin_nav_select_links.detect { |link| link[:title].match(/invoices/i) } if controller_name == "invoices" && action_name == "edit"
    end
    @admin_nav_select_link_active
  end

  def admin_nav_select_prompt
    # If there is a admin_nav_select_link_active, the prompt is for the select link
    admin_nav_select_link_active.present? ? "Viewing #{admin_nav_select_link_active[:title]}" : "Admin navigation"
  end

  def admin_nav_display_view_all
    # If there is a admin_nav_select_link_active, and it matches controller
    return false unless admin_nav_select_link_active.present? && admin_nav_select_link_active[:match_controller]
    # If it's not the main page, we should have a display all link
    return true unless current_page_active?(admin_nav_select_link_active[:path])
    # Don't show "view all" if the path is the exact same
    return true if params[:period].present? && params[:period] != "all"
    # If there are any parameters that aren't
    ignored_keys = %w[render_chart sort period direction]
    (sortable_search_params.reject { |_k, v| v.blank? }.keys - ignored_keys).any?
  end

  def edit_mail_snippet_path_for(mail_snippet)
    if mail_snippet.organization_message?
      edit_organization_email_path(mail_snippet.kind, organization_id: mail_snippet.organization_id)
    else
      edit_admin_mail_snippet_path(mail_snippet.id)
    end
  end

  def credibility_scorer_color(score)
    return "#dc3545" if score < 31
    return "#ffc107" if score < 70
    "#28a745"
  end
end
