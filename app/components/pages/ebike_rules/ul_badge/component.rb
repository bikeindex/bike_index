# frozen_string_literal: true

module Pages
  module EbikeRules
    module UlBadge
      class Component < ApplicationComponent
        # Bike Book records a certification, not its absence, so a bike is never shown as uncertified
        BACKGROUNDS = {certified: "tw:bg-[#e8f5ee]", unknown: "tw:bg-gray-100", unrecorded: "tw:bg-gray-100"}.freeze
        ICON_STATUSES = {certified: :pass, unknown: :unknown, unrecorded: :unknown}.freeze

        # standard: 2849 or 2271. status: :certified, :unknown, or :unrecorded for a bike entered by hand, with no model to have data for
        def initialize(standard:, status:)
          @standard = standard
          @status = status
        end

        private

        def title
          if @status == :certified
            translation(".certified", standard: @standard)
          else
            translation(".status_unknown", standard: @standard)
          end
        end

        def scope = (@standard == 2849) ? translation(".scope_2849") : translation(".scope_2271")

        def meaning
          case [@standard, @status]
          in [2849, :certified] then translation(".meaning_2849_system_certified")
          in [2849, :unrecorded] then translation(".meaning_2849_check_label")
          in [2849, _] then translation(".meaning_2849_unknown")
          in [_, :certified] then translation(".meaning_2271_certified")
          in [_, :unrecorded] then translation(".meaning_2271_check_label")
          else translation(".meaning_2271_unknown")
          end
        end
      end
    end
  end
end
