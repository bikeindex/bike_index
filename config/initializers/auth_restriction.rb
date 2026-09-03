module AuthRestriction
  def self.user_from(req)
    auth = req.cookie_jar.signed[ControllerHelpers::AUTH_COOKIE_KEY]
    User.from_auth(auth)
  rescue
    nil
  end

  class Developer
    def self.matches?(req)
      AuthRestriction.user_from(req)&.developer? || false
    end
  end

  class Superuser
    def self.matches?(req)
      AuthRestriction.user_from(req)&.superuser? || false
    end
  end
end
