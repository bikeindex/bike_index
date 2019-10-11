class ExternalRegistryCredential < ActiveRecord::Base
  def self.types
    %w[
      Project529Credential
    ].map { |type| [to_s, type].join("::") }
  end

  def registry_name
    self.class.to_s.split("::").last.chomp("Credential")
  end

  def access_token_valid?
    return if access_token_expires_at.blank?
    Time.current < access_token_expires_at
  end

  def access_token_expired?
    return true unless access_token_valid?
    errors.add(:access_token, "not expired")
    false
  end

  def api
    raise NotImplementedError
  end
end
