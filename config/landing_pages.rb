module LandingPages
  ORGANIZATIONS = (ENV["ORGANIZATIONS_WITH_LANDING_PAGES"] || "ikes university").split(" ").freeze
end
