# frozen_string_literal: true

module Pages
  module EbikeRules
    module UlBadge
      # A UL standard's certification status for a bike, and what that status means
      class Component < ApplicationComponent
        BACKGROUNDS = {certified: "tw:bg-[#e8f5ee]", not: "tw:bg-[#fdecec]", unknown: "tw:bg-gray-100"}.freeze
        ICON_STATUSES = {certified: :pass, not: :fail, unknown: :unknown}.freeze

        # standard: 2849 or 2271. status: :certified, :not or :unknown
        def initialize(standard:, status:)
          @standard = standard
          @status = status
        end

        private

        def title
          case @status
          when :certified then translation(".certified", standard: @standard)
          when :not then translation(".not_certified", standard: @standard)
          else translation(".status_unknown", standard: @standard)
          end
        end

        def scope = (@standard == 2849) ? translation(".scope_2849") : translation(".scope_2271")

        def meaning
          case [@standard, @status]
          in [2849, :certified] then translation(".meaning_2849_certified")
          in [2849, :not] then translation(".meaning_2849_not")
          in [2849, _] then translation(".meaning_2849_unknown")
          in [_, :certified] then translation(".meaning_2271_certified")
          in [_, :not] then translation(".meaning_2271_not")
          else translation(".meaning_2271_unknown")
          end
        end
      end
    end
  end
end
