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
class ExternalRegistryCredential::StopHelingCredential < ExternalRegistryCredential
  validates :app_id, :access_token, presence: true

  def access_token_valid?
    true
  end

  def access_token_can_be_reset?
    false
  end

  def hmac_key(search_term)
    raise ArgumentError, "search term required" if search_term.blank?

    date = Time.now.in_time_zone("Amsterdam").strftime("%Y%m%d")
    data = "#{search_term}#{date}#{app_id}"

    digest = OpenSSL::Digest.new("md5")
    OpenSSL::HMAC.hexdigest(digest, access_token, data).upcase
  end
end
