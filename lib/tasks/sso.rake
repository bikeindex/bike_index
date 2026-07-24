# Idempotently create/refresh a local "SSO Test" organization wired to the Keycloak IdP
# from https://github.com/bikeindex/saml-idp-test, for exercising the SAML SSO login flow
# end-to-end in development. Re-run any time to bring the org back to the expected shape as
# the SSO feature evolves.
#
#   bundle exec rails sso:setup_test_org
#
# Requires the Keycloak container running (`docker compose up` in the saml-idp-test repo).
# Keycloak mints its realm signing cert on first boot, so the task reads the live descriptor
# each run — recreating the container and re-running keeps the org's idp_cert current.
# Override the IdP base URL with KEYCLOAK_URL (default http://localhost:8080).
require "net/http"

namespace :sso do
  desc "Create/refresh the local SSO Test organization wired to the Keycloak test IdP"
  task setup_test_org: :environment do
    abort "sso:setup_test_org only runs in development" unless Rails.env.development?

    keycloak_url = ENV.fetch("KEYCLOAK_URL", "http://localhost:8080")
    realm = "bikeindex-test"
    domain = "ssotest.example"
    feature_slugs = %w[saml_sso] # implies passwordless_users, which provisioning runs through

    descriptor_url = "#{keycloak_url}/realms/#{realm}/protocol/saml/descriptor"
    puts "→ Reading IdP descriptor: #{descriptor_url}"
    xml = begin
      Net::HTTP.get(URI(descriptor_url))
    rescue => e
      abort <<~MSG
        Could not reach Keycloak (#{e.message}).
        Start it: clone https://github.com/bikeindex/saml-idp-test and run `docker compose up`.
      MSG
    end

    idp = Nokogiri::XML(xml).remove_namespaces!
    idp_entity_id = idp.at_xpath("//EntityDescriptor/@entityID")&.value
    idp_sso_target_url = idp.at_xpath("//SingleSignOnService[contains(@Binding, 'HTTP-POST')]/@Location")&.value ||
      idp.at_xpath("//SingleSignOnService/@Location")&.value
    idp_cert = idp.at_xpath("//KeyDescriptor[@use='signing']//X509Certificate")&.text ||
      idp.at_xpath("//X509Certificate")&.text
    if idp_entity_id.blank? || idp_sso_target_url.blank? || idp_cert.blank?
      abort "#{descriptor_url} didn't return a usable SAML IdP descriptor (entityID / SSO URL / signing cert)."
    end

    feature = OrganizationFeature.find_or_create_by!(name: "SSO Test (#{feature_slugs.join(" + ")})")
    feature.update!(feature_slugs:, amount_cents: 0)

    org = Organization.friendly_find("sso-test") || Organization.new(name: "SSO Test", kind: "school")
    org.user_email_domain = domain
    org.skip_update = true # skip the async associations job; the save below recomputes features
    org.save!

    unless org.current_invoices.feature_slugs.include?("saml_sso")
      invoice = Invoice.create!(organization: org, amount_due: 0, start_at: Time.current - 1.hour, is_endless: true)
      invoice.update!(organization_feature_ids: [feature.id])
      org.reload
      org.skip_update = true
      org.save! # recompute enabled_feature_slugs from the new invoice
    end

    config = org.organization_saml_configuration || org.build_organization_saml_configuration
    config.update!(enabled: true, idp_entity_id:, idp_sso_target_url:, idp_cert:,
      name_id_format: "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress")

    sp_configured = ENV["SAML_SP_CERTIFICATE"].present? && ENV["SAML_SP_PRIVATE_KEY"].present?
    base_url = ENV.fetch("BASE_URL", "http://localhost:3042")

    puts <<~SUMMARY

      ✓ Organization  #{org.name}  (slug: #{org.to_param}, id: #{org.id})
      ✓ Email domain  #{org.user_email_domain}
      ✓ Features      #{org.enabled_feature_slugs.select { feature_slugs.include?(it) }.join(", ")}
      ✓ SAML config   enabled=#{config.enabled?}  configured?=#{config.configured?}
                      idp_entity_id=#{config.idp_entity_id}
      #{sp_configured ? "✓" : "✗"} SP keypair    #{sp_configured ? "present" : "MISSING — set SAML_SP_CERTIFICATE / SAML_SP_PRIVATE_KEY in .env.local (saml-idp-test README step 1)"}

      Log in:     #{base_url}/sso/#{org.to_param}/init
      Test user:  ssouser@#{domain} / password
    SUMMARY
  end
end
