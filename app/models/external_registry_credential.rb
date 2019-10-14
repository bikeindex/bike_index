class ExternalRegistryCredential < ActiveRecord::Base
  validates :type, uniqueness: true
  validates :app_id, uniqueness: { scope: :type }

  # The list of acceptable STI types.
  #
  # Return an array containing each ExternalRegistryCredential subclass name,
  # stringified and without the namespace prepended.
  def self.types
    %w[
      Project529Credential
    ].map { |type| [to_s, type].join("::") }
  end

  # The registry name for receiver record. Inferred from the class name.
  def registry_name
    self.class.to_s.split("::").last.chomp("Credential")
  end

  # Return true if the access token expiration is set and the access_token has
  # not yet expired.
  def access_token_valid?
    return false if access_token_expires_at.blank?
    Time.current < access_token_expires_at
  end

  # Set an error and return false if access_token is not yet expired.
  def access_token_can_be_reset?
    return true unless access_token_expires_at.present? && access_token_valid?
    errors.add(:access_token, "not expired")
    false
  end

  def api
    raise NotImplementedError
  end
end
