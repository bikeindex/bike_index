class ExternalRegistryCredential < ActiveRecord::Base
  validates :type, uniqueness: true
  validates :app_id, uniqueness: { scope: :type }

  attr_reader :api

  # The list of acceptable STI types.
  #
  # Return an array containing each ExternalRegistryCredential subclass name,
  # stringified.
  def self.types
    subclasses = %w[
      Project529Credential
      StopHelingCredential
    ]

    subclasses
      .map { |subclass_name| [to_s, subclass_name] }
      .map { |namespace, subclass| "#{namespace}::#{subclass}" }
  end

  # The registry name for receiver record. Inferred from the class name.
  def registry_name
    credential_classname = self.class.to_s.split("::").last
    credential_classname.chomp("Credential")
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
end
