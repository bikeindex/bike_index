# This is a class so that we can test that we're including the relevant routes
class SitemapPages
  INFORMATION = %w[about ambassadors_current ambassadors_how_to
    bike_shop_packages campus_packages cities_packages for_bike_shops for_community_groups
    for_cities for_law_enforcement for_schools help donate protect_your_bike serials about
    where resources image_resources privacy terms vendor_terms security how_not_to_buy_stolen
    dev_and_design lightspeed ascend why-donate membership].freeze

  ADDITIONAL = ["where", "organizations/new", "documentation/api_v3", "recovery_stories"].freeze
end
