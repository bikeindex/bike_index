module MarketplaceShipping
  module PackageEstimator
    extend Functionable

    # BikeFlights' own box sizes. They decline to map bike type to a box ("measure your bike as
    # you will pack it"), so these are their two both-wheels-removed sizes - how a shop packs.
    MEDIUM = {length: 45, width: 12, height: 30}.freeze
    EXTRA_LARGE = {length: 56, width: 21, height: 32}.freeze

    # PROVISIONAL - we store no bike weight, so a packed box is assumed rather than measured.
    # Under-estimating costs the difference plus a $27 penalty when carriers re-measure in
    # transit, which is why the shop reweighs at drop-off and we re-quote before buying a label.
    MEDIUM_WEIGHT_POUNDS = 45
    EXTRA_LARGE_WEIGHT_POUNDS = 55

    LARGE_FRAME_CENTIMETERS = 58
    LARGE_FRAME_INCHES = 23
    LARGE_FRAME_ORDINALS = %w[l xl xxl].freeze

    def estimate_for(bike)
      if large_frame?(bike)
        EXTRA_LARGE.merge(weight_pounds: EXTRA_LARGE_WEIGHT_POUNDS)
      else
        MEDIUM.merge(weight_pounds: MEDIUM_WEIGHT_POUNDS)
      end
    end

    #
    # private below here
    #

    # Frame size is unreliable - blank on plenty of bikes, and either a number with a unit or an
    # ordinal. Anything we can't read falls to the medium box, which the shop corrects.
    def large_frame?(bike)
      case bike&.frame_size_unit
      when "cm" then bike.frame_size_number.to_f >= LARGE_FRAME_CENTIMETERS
      when "in" then bike.frame_size_number.to_f >= LARGE_FRAME_INCHES
      when "ordinal" then LARGE_FRAME_ORDINALS.include?(bike.frame_size)
      else false
      end
    end

    conceal :large_frame?
  end
end
