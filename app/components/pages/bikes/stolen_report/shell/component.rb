# frozen_string_literal: true

module Pages
  module Bikes
    module StolenReport
      module Shell
        # The gray full-bleed page the stolen report and recovery pages share: the bike's header above,
        # the donation strip below
        class Component < ApplicationComponent
          STATUSES = %i[report stolen recovered registration].freeze

          # status: :report before the theft is reported, then the badge the bike carries.
          # b_param in place of bike: the registration the report is waiting on, before its bike exists
          def initialize(bike: nil, b_param: nil, status: :report, donation_strip: true)
            @bike = bike
            @b_param = b_param
            @status = (@bike.present? && STATUSES.include?(status)) ? status : :registration
            @donation_strip = donation_strip
          end

          private

          def image_url = @bike&.image_url(:small)

          def heading
            [year, mnfg_name].compact_blank.join(" ").presence ||
              translation(".your_bike", bike_type: (@bike || @b_param).type_titleize)
          end

          def year = @bike ? @bike.year : @b_param.bike["year"]

          def mnfg_name = @bike ? @bike.mnfg_name : @b_param.mnfg_name

          def frame_model = @bike ? @bike.frame_model : @b_param.bike["frame_model"]

          def subtitle
            return registration_subtitle if @bike.blank?

            [(translation(".serial", serial: @bike.serial_display) unless @bike.no_serial?),
              @bike.frame_colors.to_sentence.presence, @bike.type_titleize].compact.join(" · ")
          end

          def registration_subtitle
            serial = @b_param.bike["serial_number"]
            serial.present? ? translation(".serial", serial:) : translation(".not_registered_yet")
          end
        end
      end
    end
  end
end
