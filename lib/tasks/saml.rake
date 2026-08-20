# frozen_string_literal: true

namespace :saml do
  desc "Generate a self-signed SP keypair for SAML_SP_CERTIFICATE / SAML_SP_PRIVATE_KEY (YEARS=50)"
  task generate_sp_keypair: :environment do
    # Long-lived on purpose: an IdP trusts this cert because it is in our registered metadata,
    # not via PKI, so expiry buys no security - it only risks an outage nothing warns us about.
    years = (ENV["YEARS"].presence || 50).to_i
    common_name = URI.parse(ENV["BASE_URL"].to_s).host.presence || "bikeindex.org"
    key = OpenSSL::PKey::RSA.new(2048)

    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = OpenSSL::BN.rand(160)
    cert.subject = cert.issuer = OpenSSL::X509::Name.new([["CN", common_name]])
    cert.public_key = key.public_key
    cert.not_before = Time.current
    cert.not_after = cert.not_before + years.years
    cert.sign(key, OpenSSL::Digest.new("SHA256"))

    puts "# Self-signed SP keypair valid until #{cert.not_after.utc.iso8601}."
    puts "# Set these as env vars (never commit the private key):\n\n"
    puts "SAML_SP_CERTIFICATE:\n#{cert.to_pem}"
    puts "SAML_SP_PRIVATE_KEY:\n#{key.to_pem}"

    # Kamal and Cloud 66 store one line per secret, so a deploy environment takes these instead
    puts "# One-line form, for a deploy environment:\n\n"
    puts "SAML_SP_CERTIFICATE:\n#{Base64.strict_encode64(cert.to_pem)}\n\n"
    puts "SAML_SP_PRIVATE_KEY:\n#{Base64.strict_encode64(key.to_pem)}\n\n"
  end
end
