class SuperuserRestriction
  def self.matches?(req)
    auth = req.cookie_jar.signed[ControllerHelpers::AUTH_COOKIE_KEY]
    User.from_auth(auth)&.superuser?
  rescue
    false
  end
end
