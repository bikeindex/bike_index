module ExternalRegistry
  class Project529Credentials
    ACCESS_TOKEN = ENV["PROJECT_529_ACCESS_TOKEN"]
    REFRESH_TOKEN = ENV["PROJECT_529_REFRESH_TOKEN"]
    APP_ID = ENV["PROJECT_529_APP_ID"]
    CREDS_KEY = "project529_credentials"

    attr_accessor :conn

    def initialize(connection:)
      self.conn = connection
    end

    def refresh_access_token
      response = conn.post("oauth/token") do |req|
        req.headers["Content-Type"] = "application/json"
        req.params = {
          grant_type: "refresh_token",
          client_id: APP_ID,
          refresh_token: refresh_token,
        }
      end

      if response.body.key?("access_token")
        Rails.cache.write(CREDS_KEY, response.body)
      else
        raise Project529ClientCredentialRefreshError, response.body
      end
    end

    def expired?(response_body)
      return unless response_body.respond_to?(:fetch)
      response_body.fetch("error", "").match?(/access token expired/)
    end

    def invalid?(response_body)
      return unless response_body.respond_to?(:fetch)
      response_body.fetch("error", "").match?(/access token is invalid/)
    end

    def delete
      Rails.cache.delete(CREDS_KEY)
    end

    def credentials
      Rails.cache.fetch(CREDS_KEY) || {}
    end

    def access_token
      credentials["access_token"].presence || ACCESS_TOKEN
    end

    def refresh_token
      credentials["refresh_token"].presence || REFRESH_TOKEN
    end
  end

  class Project529ClientCredentialRefreshError < Project529ClientError; end
end
