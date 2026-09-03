# Not `LandingPages` - `Pages::LandingPages` would shadow it for every component nested in
# `module Pages`, which fails only where one happens to read it
module LandingPageOrganizations
  SLUGS = (ENV["ORGANIZATIONS_WITH_LANDING_PAGES"] || "brakebills").split(" ").freeze
end
