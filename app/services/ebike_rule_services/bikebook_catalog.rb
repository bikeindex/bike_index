# frozen_string_literal: true

module EbikeRuleServices
  # What an e-vehicle classification's id in the Bike Book catalog says about e-bikes
  module BikebookCatalog
    # A jurisdiction's whole e-bike law, rather than one class or tier of it, by which one a state with two goes by
    E_BIKE_LAWS = %w[electric_bicycle low_speed_electric_bicycle bicycle].freeze
    E_BIKE_LAW = %r{/(#{E_BIKE_LAWS.join("|")})\z}
    US_CLASS = %r{\Aevc/us/class_(\d)\z}
  end
end
