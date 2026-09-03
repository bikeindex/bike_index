# Mints SAMLResponses with a signed assertion for request specs, using ruby-saml's own
# XMLSecurity signing (the same primitive a real IdP uses) — no external IdP needed.
# Each forge-able option lets a spec break exactly one individually-validated field.
module SamlHelpers
  SAML_NS = "urn:oasis:names:tc:SAML:2.0:assertion"
  SAMLP_NS = "urn:oasis:names:tc:SAML:2.0:protocol"
  MD_NS = "urn:oasis:names:tc:SAML:2.0:metadata"
  XMLENC_NS = "http://www.w3.org/2001/04/xmlenc#"
  XMLDSIG_NS = "http://www.w3.org/2000/09/xmldsig#"
  EMAIL_OID = OrganizationSamlConfiguration::DEFAULT_EMAIL_ATTRIBUTE

  def saml_idp_key
    @saml_idp_key ||= OpenSSL::PKey::RSA.new(File.read(Rails.root.join("spec/fixtures/saml/idp_key.pem")))
  end

  def saml_idp_cert
    @saml_idp_cert ||= OpenSSL::X509::Certificate.new(File.read(Rails.root.join("spec/fixtures/saml/idp_cert.pem")))
  end

  def saml_sp_cert
    @saml_sp_cert ||= OpenSSL::X509::Certificate.new(File.read(Rails.root.join("spec/fixtures/saml/sp_cert.pem")))
  end

  # The AuthnRequest ID from an init redirect (HTTP-Redirect binding = deflated + base64)
  def saml_request_id_from_redirect(location)
    saml_request = Rack::Utils.parse_query(URI.parse(location).query)["SAMLRequest"]
    inflated = Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(Base64.decode64(saml_request))
    Nokogiri::XML(inflated).root["ID"]
  end

  def signed_saml_response(audience:, recipient:, in_response_to:, email:,
    name_id: nil, issuer: "https://idp.example.edu/", not_on_or_after: nil,
    sign: true, tamper: false, encrypt: false, email_attribute: EMAIL_OID)
    name_id ||= email
    not_on_or_after ||= (Time.current + 5.minutes).utc.iso8601
    assertion_id = "_#{SecureRandom.uuid}"

    assertion = collapse(saml_assertion_xml(assertion_id:, issuer:, name_id:, email:, email_attribute:,
      audience:, recipient:, in_response_to:, not_on_or_after:))
    assertion = sign_saml_assertion(assertion, assertion_id) if sign
    if tamper
      assertion = assertion.sub(%r{(<ds:SignatureValue[^>]*>)[^<]+}, '\1TAMPEREDSIGNATUREVALUE==')
    end
    assertion = encrypted_assertion_xml(assertion) if encrypt

    # Collapse only the wrapper, then inject the signed assertion so its signed bytes stay intact
    wrapper = collapse(saml_response_xml(issuer:, destination: recipient, in_response_to:, assertion: "SIGNED_ASSERTION"))
    Base64.strict_encode64(wrapper.sub("SIGNED_ASSERTION", assertion))
  end

  private

  # Strip whitespace between tags (the signed assertion has none, so this leaves it byte-intact)
  def collapse(xml)
    xml.gsub(/>\s+</, "><").strip
  end

  # What an IdP that encrypts does: a one-off AES key encrypts the assertion, and the SP's
  # public key — the one our metadata publishes — encrypts that AES key.
  def encrypted_assertion_xml(assertion_xml)
    cipher = OpenSSL::Cipher.new("AES-256-CBC").encrypt
    session_key = cipher.random_key
    ciphertext = cipher.random_iv + cipher.update(assertion_xml) + cipher.final
    encrypted_key = saml_sp_cert.public_key
      .public_encrypt(session_key, OpenSSL::PKey::RSA::PKCS1_OAEP_PADDING)

    collapse(<<~XML)
      <saml:EncryptedAssertion xmlns:saml="#{SAML_NS}">
        <xenc:EncryptedData xmlns:xenc="#{XMLENC_NS}" Type="#{XMLENC_NS}Element">
          <xenc:EncryptionMethod Algorithm="#{XMLENC_NS}aes256-cbc"/>
          <ds:KeyInfo xmlns:ds="#{XMLDSIG_NS}">
            <xenc:EncryptedKey>
              <xenc:EncryptionMethod Algorithm="#{XMLENC_NS}rsa-oaep-mgf1p"/>
              <xenc:CipherData><xenc:CipherValue>#{Base64.strict_encode64(encrypted_key)}</xenc:CipherValue></xenc:CipherData>
            </xenc:EncryptedKey>
          </ds:KeyInfo>
          <xenc:CipherData><xenc:CipherValue>#{Base64.strict_encode64(ciphertext)}</xenc:CipherValue></xenc:CipherData>
        </xenc:EncryptedData>
      </saml:EncryptedAssertion>
    XML
  end

  def sign_saml_assertion(assertion_xml, assertion_id)
    document = XMLSecurity::Document.new(assertion_xml)
    document.uuid = assertion_id
    document.sign_document(saml_idp_key, saml_idp_cert,
      XMLSecurity::Document::RSA_SHA256, XMLSecurity::Document::SHA256)
    document.to_s
  end

  def saml_assertion_xml(assertion_id:, issuer:, name_id:, email:, email_attribute:,
    audience:, recipient:, in_response_to:, not_on_or_after:)
    now = Time.current.utc.iso8601
    not_before = (Time.current - 5.minutes).utc.iso8601
    <<~XML
      <saml:Assertion xmlns:saml="#{SAML_NS}" xmlns:samlp="#{SAMLP_NS}" ID="#{assertion_id}" Version="2.0" IssueInstant="#{now}">
        <saml:Issuer>#{issuer}</saml:Issuer>
        <saml:Subject>
          <saml:NameID Format="urn:oasis:names:tc:SAML:2.0:nameid-format:emailAddress">#{name_id}</saml:NameID>
          <saml:SubjectConfirmation Method="urn:oasis:names:tc:SAML:2.0:cm:bearer">
            <saml:SubjectConfirmationData InResponseTo="#{in_response_to}" NotOnOrAfter="#{not_on_or_after}" Recipient="#{recipient}"/>
          </saml:SubjectConfirmation>
        </saml:Subject>
        <saml:Conditions NotBefore="#{not_before}" NotOnOrAfter="#{not_on_or_after}">
          <saml:AudienceRestriction><saml:Audience>#{audience}</saml:Audience></saml:AudienceRestriction>
        </saml:Conditions>
        <saml:AuthnStatement AuthnInstant="#{now}" SessionIndex="#{assertion_id}">
          <saml:AuthnContext><saml:AuthnContextClassRef>urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport</saml:AuthnContextClassRef></saml:AuthnContext>
        </saml:AuthnStatement>
        <saml:AttributeStatement>
          <saml:Attribute Name="#{email_attribute}" NameFormat="urn:oasis:names:tc:SAML:2.0:attrname-format:uri">
            <saml:AttributeValue>#{email}</saml:AttributeValue>
          </saml:Attribute>
        </saml:AttributeStatement>
      </saml:Assertion>
    XML
  end

  def saml_response_xml(issuer:, destination:, in_response_to:, assertion:)
    now = Time.current.utc.iso8601
    <<~XML
      <samlp:Response xmlns:samlp="#{SAMLP_NS}" xmlns:saml="#{SAML_NS}" ID="_#{SecureRandom.uuid}" Version="2.0" IssueInstant="#{now}" Destination="#{destination}" InResponseTo="#{in_response_to}">
        <saml:Issuer>#{issuer}</saml:Issuer>
        <samlp:Status><samlp:StatusCode Value="urn:oasis:names:tc:SAML:2.0:status:Success"/></samlp:Status>
        #{assertion}
      </samlp:Response>
    XML
  end
end

# Point the SP keypair + BASE_URL at fixtures for any example tagged `:saml_env`,
# restoring the originals afterward.
RSpec.shared_context "saml_env" do
  let(:sp_cert_pem) { File.read(Rails.root.join("spec/fixtures/saml/sp_cert.pem")) }
  let(:sp_key_pem) { File.read(Rails.root.join("spec/fixtures/saml/sp_key.pem")) }
  let(:sp_cert) { sp_cert_pem }
  let(:sp_key) { sp_key_pem }

  around do |example|
    original = ENV.values_at("SAML_SP_CERTIFICATE", "SAML_SP_PRIVATE_KEY", "BASE_URL")
    ENV["SAML_SP_CERTIFICATE"] = sp_cert
    ENV["SAML_SP_PRIVATE_KEY"] = sp_key
    ENV["BASE_URL"] = "https://bikeindex.org"
    example.run
    ENV["SAML_SP_CERTIFICATE"], ENV["SAML_SP_PRIVATE_KEY"], ENV["BASE_URL"] = original
  end
end

# An organization that forces SSO for sso.edu, for any example tagged `:sso_organization`.
RSpec.shared_context "sso_organization" do
  let!(:organization) do
    FactoryBot.create(:organization_with_organization_features,
      enabled_feature_slugs: ["saml_sso"], user_email_domain: "sso.edu")
  end
  let!(:saml_configuration) { FactoryBot.create(:organization_saml_configuration, :active, organization:) }
end

RSpec.configure do |config|
  config.include SamlHelpers, type: :request
  config.include_context "saml_env", :saml_env
  config.include_context "sso_organization", :sso_organization
end
