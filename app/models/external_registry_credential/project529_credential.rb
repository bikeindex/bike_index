class ExternalRegistryCredential
  class Project529Credential < ExternalRegistryCredential
    BASE_URL = ENV.fetch("PROJECT_529_BASE_URL", "https://project529.com/garage/services/v1")
    TIMEOUT_SECS = ENV.fetch("EXTERNAL_REGISTRY_REQUEST_TIMEOUT", 5).to_i

    validates :type, uniqueness: true
    validates :app_id, :refresh_token, presence: true
    validates :app_id, uniqueness: { scope: :type }

    def set_access_token
      return unless access_token_expired?

      credentials = api&.get_oauth_token
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

    def api
      @api ||= ExternalRegistry::Project529Client.new
    end
  end
end
