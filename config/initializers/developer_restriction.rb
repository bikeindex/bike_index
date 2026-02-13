class DeveloperRestriction
  def self.matches?(req)
    auth = req.cookie_jar.signed[ControllerHelpers::AUTH_COOKIE_KEY]
    User.from_auth(auth)&.developer?
  rescue
    false
  end
end
