# This class parses bike search log lines
class LogSearcher::Parser
  CONTROLLER_ENDPOINTS = {
    "API::V1::BikesController#index" => :api_v1_bikes,
    "API::V1::BikesController#stolen_ids" => :api_v1_stolen_ids,
    "API::V1::BikesController#close_serials" => :api_v1_close_serials,
    "BikesController#index" => :public_bikes,
    "Organized::BikesController#index" => :org_bikes,
    "Admin::BikesController#index" => :admin_bikes,
    "OrgPublic::ImpoundedBikesController#index" => :org_public_impounded,
    "Organized::ImpoundRecordsController#index" => :org_impounded,
    "Organized::ParkingNotificationsController#index" => :org_parking_notifications
  }.freeze

  ROUTE_ENDPOINTS = {
    "/api/v2/bikes_search/count" => :api_v2_count,
    "/api/v2/bikes_search/close_serials" => :api_v2_close_serials,
    "/api/v3/search" => :api_v3_bikes,
    "/api/v3/search/count" => :api_v3_count,
    "/api/v3/search/close_serials" => :api_v3_close_serials,
    "/api/v3/search/serials_containing" => :api_v3_serials_containing,
    "/api/v3/search/external_registries" => :api_v3_external_registries
  }.freeze

  class << self
    def parse_log_line(log_line)
      raise "Multiple line_data matches for log line #{log_line}" if log_line.match?(/\] \{.*\] \{/)
      line_data, opts = log_line.split("] {")
      opts = JSON.parse("{#{opts}")
      endpoint = parse_endpoint(opts)
      return nil unless LoggedSearch.endpoints_sym.include?(endpoint)

      query_items = (opts["params"] || {}).select { |_, value| value.present? }
      if query_items["search_secondary"].present? && query_items["search_secondary"].is_a?(Array) &&
          query_items["search_secondary"].reject(&:blank?).none?

        query_items = query_items.except("search_secondary")
      end

      {
        request_at: parse_request_time(line_data),
        request_id: line_data.split("[").last,
        duration_ms: opts["duration"]&.to_f&.round,
        user_id: opts["u_id"],
        organization_id: Organization.friendly_find_id(opts.dig("params", "organization_id")),
        endpoint: endpoint,
        ip_address: opts["remote_ip"],
        query_items: query_items.except("organization_id", "page"),
        stolenness: stolenness_for(endpoint, opts),
        serial: query_items["serial"],
        includes_query: includes_query?(query_items),
        page: [nil, "1", "undefined"].include?(query_items["page"]) ? nil : query_items["page"].to_i
      }
    end

    private

    def includes_query?(query_items)
      query_items.except("organization_id", "page", "stolenness", "location", "distance",
        "locale", "sort", "sort_direction", "render_chart", "utf8").present?
    end

    def parse_endpoint(opts)
      if opts["message"].present?
        controller_action = opts["message"].split("(").last.delete(")")
        CONTROLLER_ENDPOINTS[controller_action]
      elsif %w[/api/v2/bikes_search /api/v2/bikes_search/stolen
        /api/v2/bikes_search/non_stolen].include?(opts["path"])
        :api_v2_bikes
      else
        ROUTE_ENDPOINTS[opts["path"]]
      end
    end

    def parse_request_time(line_data)
      time_str = line_data.gsub("I, [", "").split(" #").first
      Time.parse("#{time_str} UTC")
    end

    def stolenness_for(endpoint, opts)
      if endpoint == :api_v2_bikes
        case opts["path"]
        when "/api/v2/bikes_search" then :all
        when "/api/v2/bikes_search/stolen" then :stolen
        when "/api/v2/bikes_search/non_stolen" then :non
        end
      elsif %i[org_impounded org_public_impounded].include?(endpoint)
        :impounded
      elsif endpoint == :api_v1_stolen_ids
        :stolen
      else
        case opts.dig("params", "stolenness")
        when "stolen", "proximity" then :stolen
        when "non" then :non
        when "found", "impounded" then :impounded
        else
          if opts.dig("params", "stolen").present? && ParamsNormalizer.boolean(opts.dig("params", "stolen"))
            :stolen
          else
            :all
          end
        end
      end
    end
  end
end