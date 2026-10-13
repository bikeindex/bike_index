# frozen_string_literal: true

module Pages
  module Bikes
    module StolenReport
      module Shell
        # The gray full-bleed page the stolen bike's next steps and its recovery share: the bike's
        # header above, the donation strip below
        class Component < ApplicationComponent
          # status: the badge the bike carries, :stolen or :recovered
          def initialize(bike:, status:, donation_strip: true)
            @bike = bike
            @status = status
            @donation_strip = donation_strip
          end

          def before_render
            @image_url = @bike.image_url(:small)
          end

          private

          # The emailed recovery link reaches the recovered page signed out
          def editable? = @bike.authorized?(helpers.current_user)

          def heading
            [@bike.year, @bike.mnfg_name].compact_blank.join(" ").presence ||
              translation(".your_bike", bike_type: @bike.type_titleize)
          end

          def subtitle
            [(translation(".serial", serial: @bike.serial_display) unless @bike.no_serial?),
              @bike.frame_colors.to_sentence.presence, @bike.type_titleize].compact.join(" · ")
          end
        end
      end
    end
  end
end
