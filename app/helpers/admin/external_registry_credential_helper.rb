module Admin::ExternalRegistryCredentialHelper
  def external_registry_type_options
    types = ExternalRegistryCredential.types
    labels = types.map { |type| type.split("::").last }
    options_for_select(labels.zip(types))
  end

  def external_registry_credential_expires_in(external_registry_credential)
    expiration_dt = external_registry_credential.access_token_expires_at

    return if expiration_dt.blank?
    return "unset" if external_registry_credential.access_token.blank?
    return "expired" unless external_registry_credential.access_token_valid?

    distance_of_time_in_words(Time.current, expiration_dt)
  end
end
