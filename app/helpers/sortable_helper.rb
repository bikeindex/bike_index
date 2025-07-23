# frozen_string_literal: true

module SortableHelper
  DEFAULT_SEARCH_KEYS = [
    :direction, :sort, # sorting params
    :period, :start_time, :end_time, :time_range_column, :render_chart, # Time period params
    :user_id, :organization_id, :query, # General search params
    :serial, :stolenness, :location, :distance, :primary_activity, query_items: [] # Bike searching params
  ].freeze

  def sortable(column, title = nil, html_options = {}, &block)
    if title.is_a?(Hash) # If title is a hash, it wasn't passed
      html_options = title
      title = nil
    end
    title ||= column.gsub(/_(id|at)\z/, "").titleize

    # Check for render_sortable - otherwise default to rendering
    render_sortable = html_options.key?(:render_sortable) ? html_options[:render_sortable] : !html_options[:skip_sortable]
    return title unless render_sortable
    html_options[:class] = "#{html_options[:class]} sortable-link"
    direction = (column == sort_column && sort_direction == "desc") ? "asc" : "desc"

    if column == sort_column
      html_options[:class] += " active"
      span_content = (direction == "asc") ? "\u2193" : "\u2191"
    end

    link_to(sortable_url(column, direction), html_options) do
      concat(block_given? ? capture(&block) : title.html_safe)
      concat(content_tag(:span, span_content, class: "sortable-direction"))
    end
  end

  def sortable_search_params?(except: [])
    except_keys = %i[direction sort period per_page] + except
    s_params = sortable_search_params.except(*except_keys).values.reject(&:blank?).any?

    return true if s_params
    return false if except.map(&:to_s).include?("period")
    params[:period].present? && params[:period] != "all"
  end

  def sortable_search_params
    return @sortable_search_params if defined?(@sortable_search_params)

    search_param_keys = params.keys.select { |k| k.to_s.start_with?("search_") } # match params starting with search_
    @sortable_search_params = params.permit(*(DEFAULT_SEARCH_KEYS | search_param_keys))
  end

  private

  # This is a separate method purely for testing purposes
  def sortable_url(sort, direction)
    url_for(sortable_search_params.merge(sort:, direction:))
  end
end
