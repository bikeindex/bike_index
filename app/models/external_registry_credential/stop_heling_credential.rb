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
