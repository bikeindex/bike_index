# frozen_string_literal: true

module Pages
  module EbikeRules
    module ClassTile
      # An e-bike class's navy tile, or the red e-moto tile for a bike with no class
      class Component < ApplicationComponent
        SIZES = {
          md: {tile: "tw:size-14", label: "tw:text-[9px]", number: "tw:text-[28px]", icon: "tw:size-6"},
          lg: {tile: "tw:size-19", label: "tw:text-[11px]", number: "tw:text-[40px]", icon: "tw:size-8"}
        }.freeze

        def initialize(e_bike_class:, size: :md)
          @e_bike_class = e_bike_class
          @size = SIZES.fetch(size)
        end

        def call
          tag.div(class: "#{@size[:tile]} tw:flex tw:flex-none tw:flex-col tw:items-center tw:justify-center tw:rounded-lg tw:leading-none tw:text-white #{@e_bike_class ? "tw:bg-slate-900" : "tw:bg-[#cc0000]"}",
            aria: @e_bike_class ? {label: translation(".class_aria", n: @e_bike_class)} : {hidden: true},
            role: ("img" if @e_bike_class)) do
            @e_bike_class ? class_number : emoto
          end
        end

        private

        def class_number
          tag.span(translation(".class"), class: "#{@size[:label]} tw:font-bold tw:tracking-[.12em] tw:text-[#ffd660] tw:uppercase") +
            tag.span(@e_bike_class, class: "#{@size[:number]} tw:mt-0.5 tw:font-header tw:font-black")
        end

        def emoto
          tag.span(translation(".emoto"), class: "#{@size[:label]} tw:font-bold tw:tracking-[.12em] tw:uppercase") +
            helpers.inline_svg_tag("icons/x.svg", class: "#{@size[:icon]} tw:mt-1 tw:p-1 tw:stroke-[2.5]", aria_hidden: true)
        end
      end
    end
  end
end
