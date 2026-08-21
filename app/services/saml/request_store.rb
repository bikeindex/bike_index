# Carries the in-flight SAML transaction from the AuthnRequest to the assertion.
#
# The session can't hold it: the IdP returns the assertion as a cross-site POST, and a
# SameSite=Lax cookie isn't sent on one, so the callback sees no session at all. The token
# travels in RelayState (signed alongside the AuthnRequest) and the state stays here - which
# is why where the user was headed rides along rather than staying in the session it began in.
module Saml
  module RequestStore
    extend Functionable

    NORMAL_MODE = "normal"
    TEST_MODE = "test"

    # Long enough for a password prompt and an MFA challenge, short enough that an
    # intercepted RelayState is worthless by the time it's used.
    TTL = 10.minutes

    def create(request_id:, org_slug:, return_to: nil, mode: NORMAL_MODE, expected_email: nil)
      SecureRandom.urlsafe_base64(24).tap do |token|
        RedisPool.conn do |r|
          r.set(key(token), [org_slug, request_id, return_to, mode, expected_email].join(SEPARATOR), ex: TTL.to_i)
        end
      end
    end

    # Reads and deletes in one operation, so an assertion replayed against a spent token
    # finds nothing even if it arrives inside the InResponseTo validity window.
    def claim(token)
      return nil if token.blank?

      raw = RedisPool.conn { |r| r.getdel(key(token)) }
      return nil if raw.blank?

      org_slug, request_id, return_to, mode, expected_email = raw.split(SEPARATOR, 5)
      {org_slug:, request_id:, return_to: return_to.presence, mode: mode.presence || NORMAL_MODE,
       expected_email: expected_email.presence}
    end

    #
    # private below here
    #
    SEPARATOR = "\n"

    def key(token)
      "saml_request:#{token}"
    end

    conceal :key
  end
end
