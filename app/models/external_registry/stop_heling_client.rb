# frozen_string_literal: true

module ExternalRegistry
  class StopHelingClient
    APP_ID = ENV["STOP_HELING_APP_ID"]
    API_KEY = ENV["STOP_HELING_API_KEY"]
    TTL_HOURS = ENV.fetch("STOP_HELING_API_TTL_HOURS", 24).to_i.hours
    TIMEOUT_SECS = ENV.fetch("EXTERNAL_REGISTRY_REQUEST_TIMEOUT", 5).to_i

    attr_accessor :conn, :base_url

    def initialize(base_url: nil)
      self.base_url = base_url || ENV["STOP_HELING_BASE_URL"]
      self.conn = Faraday.new(url: self.base_url) do |conn|
        conn.response :json, content_type: /\bjson$/
        conn.use Faraday::RequestResponseLogger::Middleware,
                 logger_level: :info,
                 logger: Rails.logger if Rails.env.development?
        conn.adapter Faraday.default_adapter
        conn.options.timeout = TIMEOUT_SECS
      end
    end

    # GET /GetSearchItems
    #
    # Query Params:
    #
    # ApplicationID   integer [required]
    # Hmac            string  [required]
    # SearchTerm      string  [required]
    # Loc             string
    # IpAddress       string
    # SearchMerk      string
    #
    # Returns an Array, any present entries of which are Hashes.
    def search(search_term, brand: nil, ip_address: nil, location: nil)
      endpoint = "GetSearchItems"
      req_params = request_params(search_term, brand, ip_address, location)
      cache_key = ["stopheling.nl", endpoint, req_params]

      response_body =
        Rails.cache.fetch(cache_key, expires_in: TTL_HOURS) do
          response = conn.get(endpoint) do |req|
            req.headers["Content-Type"] = "application/json;charset=UTF-8"
            req.params = req_params
          end
          response.body
        end

      results = results_from(response_body: response_body)
      ::ExternalRegistryBike.where(id: results.map(&:id))
    end

    private

    def request_params(search_term, brand, ip_address, location)
      query = {}
      query["ApplicationID"] = APP_ID
      query["Hmac"] = hmac(search_term)
      query["SearchTerm"] = search_term

      query["SearchMerk"] = brand if brand.present?
      query["IpAddress"] = ip_address if ip_address.present?
      query["Loc"] = location if location.present?
      query
    end

    def results_from(response_body:)
      case response_body
      when Array
        response_body
          .map { |result| translate_keys(result) }
          .map { |attrs| ExternalRegistryBikes::StopHelingBike.build_from_api_response(attrs) }
          .compact
          .each(&:save)
          .select(&:persisted?)
      else
        if Rails.env.production?
          # Fail gracefully but notify Honeybadger if the request fails.
          # Typically an HMAC key error message will be returned as a Hash.
          Honeybadger.notify("StopHeling API request failed", {
            error_class: "StopHelingClient",
            context: { request: req_params, response: response_body },
          })
        end
        []
      end
    end

    KEY_TRANSLATION = {
      "Korpscode" => :corps_code,
      "Registratienummer" => :registration_number,
      "Kleur" => :color,
      "Merk" => :brand,
      "Merktype" => :brand_type,
      "Categorie" => :category,
      "Object" => :object,
      "Kenteken_regnr" => :license_plate_number,
      "Motor_serienr" => :engine_serial_number,
      "Chassis_graveer" => :chassis_number,
      "Uniek_nummer" => :unique_number,
      "Datuminvoer" => :date_input,
      "Datumwijziging" => :change_of_date,
      "Insertdate" => :insert_date,
      "Bron" => :source,
      "BronNaam" => :source_name,
      "BronUniekID" => :source_unique_id,
      "MatchType" => :match_type,
    }

    def translate_keys(result)
      translated = result.map do |key, val|
        t_key = KEY_TRANSLATION.fetch(key, key.underscore.tr(" ", "_").to_sym)
        [t_key, val]
      end

      translated.to_h
    end

    def hmac(search_term)
      raise ArgumentError, "search term required" if search_term.blank?

      date = Time.now.in_time_zone("Amsterdam").strftime("%Y%m%d")
      data = "#{search_term}#{date}#{APP_ID}"

      digest = OpenSSL::Digest.new("md5")
      OpenSSL::HMAC.hexdigest(digest, API_KEY, data).upcase
    end
  end
end
