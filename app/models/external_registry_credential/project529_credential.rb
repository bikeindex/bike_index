# == Schema Information
#
# Table name: external_registry_credentials
# Database name: primary
#
#  id                      :integer          not null, primary key
#  access_token            :string
#  access_token_expires_at :datetime
#  info_hash               :jsonb
#  refresh_token           :string
#  type                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  app_id                  :string
#
# Indexes
#
#  index_external_registry_credentials_on_type  (type)
#
class ExternalRegistryCredential::Project529Credential < ExternalRegistryCredential
  validates :app_id, :refresh_token, presence: true

  # Our credential thought it was expired, but apparently it wasn't. See PR#2076
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
