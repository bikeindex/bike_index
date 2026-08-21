module AdminHelper
  # Params that change how a collection is displayed rather than narrowing it
  UNFILTERING_SEARCH_KEYS = %w[render_chart sort period direction].freeze

  def admin_search_filtered?
    return true if params[:period].present? && params[:period] != "all"

    (sortable_search_params.reject { |_k, v| v.blank? }.keys - UNFILTERING_SEARCH_KEYS).any?
  end

  # search_status: "all" because the index otherwise only shows the investigate statuses
  def bug_report_search_link(search_params)
    link_to search_emoji, admin_bug_reports_path(search_params.merge(search_status: "all")),
      class: "display-sortable-link small tw:ml-1"
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

  def credibility_scorer_color_table(score)
    (score < 31) ? credibility_scorer_color(score) : ""
  end

  def admin_email_domain_spam_color(spam_score)
    if spam_score > 9
      "text-danger"
    elsif spam_score < EmailDomain::SPAM_SCORE_AUTO_BAN
      "text-info"
    else
      ""
    end
  end

  def admin_path_for_object(obj = nil, item_type: nil, item_id: nil)
    if item_type.present? && item_id.present?
      return admin_path_for_object(item_type.constantize.find_by(id: item_id))
    end
    return nil unless obj&.id.present?

    if obj.instance_of?(PaperTrail::Version)
      admin_path_for_object(item_type: obj.item_type, item_id: obj.item_id)
    elsif obj.instance_of?(StolenRecord)
      admin_stolen_bike_path(obj.id, stolen_record_id: obj.id)
    elsif obj.instance_of?(ImpoundRecord)
      admin_impound_record_path("pkey-#{obj.id}")
    elsif obj.instance_of?(UserPhone)
      admin_user_path(obj.user_id)
    elsif obj.instance_of?(UserAlert)
      admin_user_alerts_path(user_id: obj.user_id)
    elsif obj.instance_of?(Blog)
      admin_news_path(obj) # blogs are administered as news
    else
      "/admin/#{obj.class.to_s.underscore.pluralize}/#{obj.id}"
    end
  end

  def theft_alert_status_class(theft_alert)
    text_class = if theft_alert.active?
      "text-info"
    elsif theft_alert.pending?
      "text-warning"
    elsif theft_alert.inactive?
      "less-strong small"
    end
    theft_alert.recovered? ? text_class + " small" : text_class
  end

  def render_admin_pagination_with_count(collection:, count: nil, skip_total: false, skip_today: false, skip_pagination: false, humanized_time_range_column_override: nil, viewing: nil)
    render(Admin::PaginationWithCount::Component.new(
      collection:,
      count:,
      skip_total:,
      skip_today:,
      skip_pagination:,
      humanized_time_range_column_override:,
      viewing:,
      pagy: @pagy,
      per_page: @per_page,
      time_range: @time_range,
      period: @period,
      time_range_column: @time_range_column,
      params:
    ))
  end

  def render_admin_current_info(viewing: nil, kind_humanized: nil)
    render(Admin::Headers::CurrentInfo::Component.new(
      params:,
      viewing:,
      kind_humanized:,
      user_subject: @user_subject,
      bike: @bike,
      marketplace_listing: @marketplace_listing,
      primary_activity: @primary_activity,
      current_organization:
    ))
  end
end
