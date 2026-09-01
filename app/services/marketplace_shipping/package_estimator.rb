module MarketplaceShipping
  module PackageEstimator
    extend Functionable

    # BikeFlights' own assembled box sizes, from bikeflights.com/dimensionsandrates. They decline
    # to map bike type to a box - "measure your bike as you will pack it" - so these are the two a
    # partner shop realistically reaches for: both are the sizes they describe as packed with both
    # wheels removed, which is how a shop packs. The medium also stays inside their best-rate
    # thresholds (48in longest side, 30in second longest).
    MEDIUM = {length: 45, width: 12, height: 30}.freeze
    EXTRA_LARGE = {length: 56, width: 21, height: 32}.freeze

    # PROVISIONAL, and the least trustworthy part of this estimate: we store no bike weight, so
    # this is a whole packed box - bike plus carton and padding - assumed rather than measured.
    # Both sit under BikeFlights' 50lb preferential-rate threshold, which is what makes an
    # under-estimate expensive: their carriers re-measure in transit and bill the difference plus
    # a $27 penalty. The shop reweighs at drop-off and we re-quote before buying a label.
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
