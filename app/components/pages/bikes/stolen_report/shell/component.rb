# frozen_string_literal: true

module Pages
  module Bikes
    module StolenReport
      module Shell
        # The gray full-bleed page the stolen report and recovery pages share: the bike's header above,
        # the donation strip below
        class Component < ApplicationComponent
          STATUSES = %i[report stolen recovered].freeze

          # status: :report before the theft is reported, then the badge the bike carries
          def initialize(bike:, status: :report, donation_strip: true)
            @bike = bike
            @status = STATUSES.include?(status) ? status : :report
            @donation_strip = donation_strip
          end

          private

          def subtitle
            [(translation(".serial", serial: @bike.serial_display) unless @bike.no_serial?),
              @bike.frame_colors.to_sentence.presence, @bike.type_titleize].compact.join(" · ")
          end

          def heading = [@bike.year, @bike.mnfg_name].compact.join(" ")
        end
      end
    end
  end
end
