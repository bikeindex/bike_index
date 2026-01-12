# frozen_string_literal: true

class CycleType
  include Enumable
  include AutocompleteHashable
  include ShortNameable

  SLUGS = {
    bike: 0,
    tandem: 1,
    unicycle: 2,
    tricycle: 3,
    stroller: 4,
    recumbent: 5,
    trailer: 6,
    wheelchair: 7,
    cargo: 8,
    "tall-bike": 9,
    "penny-farthing": 10,
    "cargo-rear": 11,
    "cargo-trike": 12,
    "cargo-trike-rear": 13,
    "trail-behind": 14,
    "pedi-cab": 15,
    "e-scooter": 16,
    "personal-mobility": 18,
    "non-e-scooter": 19,
    "non-e-skateboard": 20,
    "e-motorcycle": 21,
    elliptical: 22
  }.freeze

  DEFAULT = "Bike"
  NAMES = {
    bike: DEFAULT,
    tandem: "Tandem",
    unicycle: "Unicycle",
    tricycle: "Tricycle",
    stroller: "Stroller",
    recumbent: "Recumbent",
    trailer: "Bike Trailer",
    wheelchair: "Wheelchair",
    cargo: "Cargo Bike (front storage)",
    "tall-bike": "Tall Bike (multiple frames fused together)",
    "penny-farthing": "Penny Farthing",
    "cargo-rear": "Cargo Bike Rear (e.g. longtail)",
    "cargo-trike": "Cargo Tricycle (trike with front storage, e.g. Christiania bike)",
    "cargo-trike-rear": "Cargo Tricycle (trike with rear storage)",
    "trail-behind": "Trail behind (half bike)",
    "pedi-cab": "Pedi Cab (rickshaw)",
    "e-scooter": "e-Scooter",
    "personal-mobility": "e-Personal Mobility (EPAMD, e-Skateboard, Segway, e-Unicycle, etc)",
    "non-e-scooter": "Scooter (not electric)",
    "non-e-skateboard": "Skateboard (not electric)",
    "e-motorcycle": "e-Motorcycle/e-Dirtbike (no pedals)",
    elliptical: "Elliptical bike"
  }.freeze

  MODEST_PRIORITY = %i[personal-mobility recumbent tandem tricycle].freeze

  PEDAL = %i[bike cargo cargo-rear cargo-trike cargo-trike-rear pedi-cab penny-farthing
    recumbent tall-bike tandem trail-behind tricycle unicycle].freeze
  ALWAYS_MOTORIZED = %i[e-scooter personal-mobility e-motorcycle].freeze
  NEVER_MOTORIZED = %i[non-e-scooter non-e-skateboard trail-behind].freeze
  NOT_CYCLE_TYPE = %i[e-scooter non-e-skateboard personal-mobility stroller wheelchair e-motorcycle].freeze

  class << self
    def slug_translation_short(slug)
      slug_translation(slug)&.gsub(/\s?\([^)]*\)/i, "")
    end

    def searchable_names
      slugs
    end

    def pedal_type?(slug)
      PEDAL.include?(slug&.to_sym)
    end

    def strict_motorized(slug)
      if ALWAYS_MOTORIZED.include?(slug&.to_sym)
        :always
      elsif NEVER_MOTORIZED.include?(slug&.to_sym)
        :never
      end
    end

    def not_cycle?(slug)
      NOT_CYCLE_TYPE.include?(slug&.to_sym)
    end

    def front_and_rear_wheels?(slug)
      (PEDAL - %i[unicycle trail-behind trailer] + %i[e-scooter non-e-scooter e-motorcycle])
        .include?(slug&.to_sym)
    end

    def not_cycle_drivetrain?(slug)
      (NOT_CYCLE_TYPE + %i[trail-behind trailer unicycle]).include?(slug&.to_sym)
    end

    def select_options(traditional_bike: false)
      slugs.map do |slug|
        if slug == "bike" && traditional_bike
          [slug_translation("traditional_bike"), slug]
        else
          [slug_translation(slug), slug]
        end
      end
    end

    def default_slug
      "bike"
    end
  end

  def initialize(slug)
    @slug = slug&.to_sym
    @id = SLUGS[@slug]
  end

  attr_reader :slug, :id

  def priority
    if slug == :bike
      950
    elsif slug == :"cargo-rear"
      940
    elsif slug == :"e-scooter"
      930
    elsif MODEST_PRIORITY.include?(slug)
      920
    else
      900
    end
  end

  def short_name_translation
    self.class.slug_translation_short(slug)
  end

  def search_id
    "v_#{id}"
  end

  def autocomplete_hash
    {
      id: id,
      text: name,
      category: "cycle_type",
      priority: priority,
      data: {
        priority: priority,
        slug: slug,
        search_id: search_id
      }
    }
  end
end
