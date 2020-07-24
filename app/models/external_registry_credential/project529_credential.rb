class ExternalRegistryCredential::Project529Credential < ExternalRegistryCredential
  validates :app_id, :refresh_token, presence: true

  def set_access_token
    return unless access_token_can_be_reset?

    credentials = api&.get_oauth_token
    expires_at_unix =
      %i[created_at expires_in]
        .map { |k| credentials[k] }
        .sum

    update(
      refresh_token: credentials[:refresh_token],
      access_token: credentials[:access_token],
      access_token_expires_at: Time.at(expires_at_unix).utc
    )
  end

  def api
    @api ||= ExternalRegistryClient::Project529Client.new
  end
end
