class ExternalRegistryCredential
  class Project529Credential < ExternalRegistryCredential
    BASE_URL = ENV.fetch("PROJECT_529_BASE_URL", "https://project529.com/garage/services/v1")
    TIMEOUT_SECS = ENV.fetch("EXTERNAL_REGISTRY_REQUEST_TIMEOUT", 5).to_i

    validates :access_token,
              :access_token_expires_at,
              :refresh_token,
              :app_id,
              presence: true

    attr_accessor :api_client

    def access_token_expired?
      return true if access_token_expires_at.blank?

      access_token_expires_at < Time.current
    end

    def set_access_token
      credentials = api_client.access_token

      expires_at_unix =
        %i[created_at expires_in]
          .map { |k| credentials[k] }
          .sum

      update(
        refresh_token: credentials[:refresh_token],
        access_token: credentials[:access_token],
        access_token_expires_at: Time.at(expires_at_unix).utc,
      )
    end
  end
end
