# Mints SAMLResponses with a signed assertion for request specs, using ruby-saml's own
# XMLSecurity signing (the same primitive a real IdP uses) — no external IdP needed.
# Each forge-able option lets a spec break exactly one individually-validated field.
module SamlHelpers
  SAML_NS = "urn:oasis:names:tc:SAML:2.0:assertion"
  SAMLP_NS = "urn:oasis:names:tc:SAML:2.0:protocol"
  EMAIL_OID = OrganizationSamlConfiguration::DEFAULT_EMAIL_ATTRIBUTE

  def saml_idp_key
    @saml_idp_key ||= OpenSSL::PKey::RSA.new(File.read(Rails.root.join("spec/fixtures/saml/idp_key.pem")))
  end

  def saml_idp_cert
    @saml_idp_cert ||= OpenSSL::X509::Certificate.new(File.read(Rails.root.join("spec/fixtures/saml/idp_cert.pem")))
  end

  # The AuthnRequest ID from an init redirect (HTTP-Redirect binding = deflated + base64)
  def saml_request_id_from_redirect(location)
    saml_request = Rack::Utils.parse_query(URI.parse(location).query)["SAMLRequest"]
    inflated = Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(Base64.decode64(saml_request))
    Nokogiri::XML(inflated).root["ID"]
  end

  def signed_saml_response(audience:, recipient:, in_response_to:, email:,
    name_id: nil, issuer: "https://idp.example.edu/", not_on_or_after: nil,
    sign: true, tamper: false, email_attribute: EMAIL_OID)
    name_id ||= email
    not_on_or_after ||= (Time.current + 5.minutes).utc.iso8601
    assertion_id = "_#{SecureRandom.uuid}"

    assertion = collapse(saml_assertion_xml(assertion_id:, issuer:, name_id:, email:, email_attribute:,
      audience:, recipient:, in_response_to:, not_on_or_after:))
    assertion = sign_saml_assertion(assertion, assertion_id) if sign
    if tamper
      assertion = assertion.sub(%r{(<ds:SignatureValue[^>]*>)[^<]+}, '\1TAMPEREDSIGNATUREVALUE==')
    end

    # Collapse only the wrapper, then inject the signed assertion so its signed bytes stay intact
    wrapper = collapse(saml_response_xml(issuer:, destination: recipient, in_response_to:, assertion: "SIGNED_ASSERTION"))
    Base64.strict_encode64(wrapper.sub("SIGNED_ASSERTION", assertion))
  end

  private

  # Strip whitespace between tags (the signed assertion has none, so this leaves it byte-intact)
  def collapse(xml)
    xml.gsub(/>\s+</, "><").strip
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

RSpec.configure do |config|
  config.include SamlHelpers, type: :request
end
