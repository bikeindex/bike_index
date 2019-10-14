module ExternalRegistry
  class Project529Client
    BASE_URL = ENV.fetch("PROJECT_529_BASE_URL", "https://project529.com/garage/services/v1")
    APP_ID = ENV["PROJECT_529_APP_ID"]

    TTL_HOURS = ENV.fetch("EXTERNAL_REGISTRY_REQUEST_CACHE_TTL_HOURS", 24).to_i.hours
    TIMEOUT_SECS = ENV.fetch("EXTERNAL_REGISTRY_REQUEST_TIMEOUT", 5).to_i

    attr_accessor :conn, :base_url

    def initialize(base_url: nil)
      self.base_url = base_url || BASE_URL
      self.conn = Faraday.new(url: self.base_url) do |conn|
        conn.response :json, content_type: /\bjson$/
        conn.use Faraday::RequestResponseLogger::Middleware,
                 logger_level: :info,
                 logger: Rails.logger if Rails.env.development?
        conn.adapter Faraday.default_adapter
        conn.options.timeout = TIMEOUT_SECS
      end
    end

    def oauth_token
      response = conn.post("oauth/token") do |req|
        req.headers["Content-Type"] = "application/json"
        req.params = {
          grant_type: "refresh_token",
          client_id: credentials.app_id,
          refresh_token: credentials.refresh_token,
        }
      end

      unless response.status == 200 && response.body.is_a?(Hash)
        raise Project529ClientError, response.body
      end

      response.body.with_indifferent_access
    end

    def bikes(updated_at: nil, page: 1, per_page: 10)
      credentials.set_access_token if credentials.access_token_expired?

      req_params = {
        updated_at: (updated_at.presence || Time.current - 20.days).strftime("%Y-%m-%d"),
        page: page,
        per_page: per_page,
      }

      cache_key = [self.class.to_s, __method__.to_s, req_params]

      response =
        Rails.cache.fetch(cache_key, expires_in: TTL_HOURS) do
          response = conn.get("bikes") do |req|
            req.headers["Content-Type"] = "application/json"
            req.params = req_params.merge(access_token: credentials.access_token)
          end

          { status: response.status, body: response.body.with_indifferent_access }
        end

      case response[:status]
      when 200
        results =
          response
            .dig(:body, :bikes)
            .map { |attrs| ExternalRegistryBikes::Project529Bike.build_from_api_response(attrs) }
            .compact
            .each(&:save)
            .select(&:persisted?)
        ExternalRegistryBike.where(id: results.map(&:id))
      else
        raise Project529ClientError, response
      end
    rescue Faraday::TimeoutError
      ExternalRegistryBike.none
    end

    def credentials
      @credentials ||= Project529Credential.last.tap do |creds|
        creds.api_client = self
      end
    end
  end

  class Project529ClientError < StandardError; end
  class Project529ClientInvalidCredentialsError < Project529ClientError; end
end
