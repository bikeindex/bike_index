# frozen_string_literal: true

class ExternalRegistryClient::StopHelingClient < ExternalRegistryClient
  BASE_URL = ENV["STOP_HELING_BASE_URL"]

  def initialize(base_url: BASE_URL)
    self.base_url = base_url
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
      Rails.cache.fetch(cache_key, expires_in: TTL_HOURS) {
        response = conn.get(endpoint) { |req|
          req.headers["Content-Type"] = "application/json;charset=UTF-8"
          req.params = req_params
        }
        response.body
      }

    results_from(response_body: response_body, request_params: req_params)
  end

  private

  def request_params(search_term, brand, ip_address, location)
    query = {}
    query["ApplicationID"] = credentials.app_id
    query["Hmac"] = credentials.hmac_key(search_term)
    query["SearchTerm"] = search_term

    query["SearchMerk"] = brand if brand.present?
    query["IpAddress"] = ip_address if ip_address.present?
    query["Loc"] = location if location.present?
    query
  end

  def results_from(response_body:, request_params:)
    case response_body
    when Array
      # Exclude non-bikes, any bikes without serial numbers, since we won't be
      # searching for these.
      response_body
        .map { |result| translate_keys(result) }
        .map { |attrs| ExternalRegistryBike::StopHelingBike.build_from_api_response(attrs) }
        .compact
    else
      if Rails.env.production?
        # Fail gracefully but notify Honeybadger if the request fails.
        # Typically an HMAC key error message will be returned as a Hash.
        Honeybadger.notify("StopHeling API request failed", {
          error_class: self.class.to_s,
          context: {request: request_params, response: response_body}
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
    "MatchType" => :match_type
  }

  def translate_keys(result)
    translated = result.map { |key, val|
      t_key = KEY_TRANSLATION.fetch(key, key.underscore.tr(" ", "_").to_sym)
      [t_key, val]
    }

    translated.to_h
  end
end
