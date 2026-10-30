# frozen_string_literal: true

module Pages
  module EbikeRules
    module UlBadge
      # A UL certification a bike carries, or for one carrying neither, that its certification is unknown, each a tooltip of
      # what it means for the bike
      class Component < ApplicationComponent
        # BikeBook records a certification, not its absence, so a bike is never shown as uncertified
        BACKGROUNDS = {certified: "tw:bg-[#e8f5ee]", unknown: "tw:bg-[#fff6da]", unrecorded: "tw:bg-[#fff6da]"}.freeze
        ICON_STATUSES = {certified: :pass, unknown: :unknown_warning, unrecorded: :unknown_warning}.freeze

        # standard: 2849 or 2271, nil for neither. status: :certified, :unknown, or :unrecorded for a bike entered by hand
        def initialize(status:, standard: nil)
          @standard = standard
          @status = status
        end

        private

        def certified? = @status == :certified

        def title = certified? ? translation(".certified", standard: @standard) : translation(".certification_unknown")

        def scope = (@standard == 2849) ? translation(".scope_2849") : translation(".scope_2271")

        def meaning
          case [@standard, @status]
          in [2849, :certified] then translation(".meaning_2849_system_certified")
          in [_, :certified] then translation(".meaning_2271_certified")
          in [_, :unrecorded] then translation(".meaning_check_labels")
          else translation(".meaning_unknown")
          end
        end
      end
    end
  end
end
