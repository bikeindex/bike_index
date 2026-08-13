module LandingPages
  ORGANIZATIONS = (ENV["ORGANIZATIONS_WITH_LANDING_PAGES"] || "brakebills").split(" ").freeze
end
