# frozen_string_literal: true

module Pages
  module EbikeRules
    module ClassTile
      # An e-bike class's navy tile, a gray one for a class the catalog can't tell, or the red e-moto tile for a bike with
      # no class. `optional` is the mode - "throttle" or "assist" - that alone brings a class, whose tile is outlined and
      # captioned with it. `explained`, a class's or the e-moto's tile is a tooltip of its card, with its catalog ID: the
      # e-moto's `out_of_class_id`, evc/out_of_class/us/ca, for a vehicle in no class in that state alone
      class Component < ApplicationComponent
        SIZES = {
          md: {tile: "tw:size-14", label: "tw:text-[9px]", number: "tw:text-[28px]", icon: "tw:size-6"},
          lg: {tile: "tw:size-19", label: "tw:text-[11px]", number: "tw:text-[40px]", icon: "tw:size-8"}
        }.freeze

        def initialize(e_bike_class:, class_unknown: false, optional: nil, size: :md, explained: false, out_of_class_id: nil)
          @e_bike_class = e_bike_class
          @out_of_class_id = out_of_class_id
          @optional = optional
          @class_unknown = class_unknown
          @size = SIZES.fetch(size)
          @explained = explained
        end

        def call
          return badge unless @optional

          tag.div(class: "tw:flex tw:w-min tw:flex-col tw:items-center tw:gap-1") do
            badge + tag.span(caption, class: "tw:text-center tw:text-xs tw:leading-tight tw:text-gray-600 tw:dark:text-gray-400")
          end
        end

        private

        def badge
          return tile if !@explained || @class_unknown

          render(UI::Tooltip::Component.new(text: aria[:label] || translation(".emoto_aria"))) do |tooltip|
            tooltip.with_body { render(Pages::EbikeRules::ClassCard::Component.new(e_bike_class: @e_bike_class, framed: false, catalog_id:)) }
            tile
          end
        end

        def catalog_id = @e_bike_class ? "evc/us/class_#{@e_bike_class}" : @out_of_class_id || EbikeRuleServices::StateLaws::NOT_AN_EBIKE[:id]

        def caption = (@optional == "throttle") ? translation(".optional_throttle") : translation(".optional_upgrade")

        # a span, as a tooltip's trigger is a button
        def tile
          tag.span(class: "#{@size[:tile]} tw:flex tw:flex-none tw:flex-col tw:items-center tw:justify-center tw:rounded-lg tw:leading-none tw:text-white #{color}",
            aria: aria, role: ("img" if @e_bike_class || @class_unknown)) do
            (@e_bike_class || @class_unknown) ? class_number : emoto
          end
        end

        def color
          if @optional && @e_bike_class.nil?
            "tw:border-2 tw:border-[#cc0000] tw:text-[#cc0000]!"
          elsif @optional
            "tw:border-2 tw:border-slate-900 tw:text-slate-900! tw:dark:border-slate-300 tw:dark:text-slate-100!"
          elsif @e_bike_class
            "tw:bg-slate-900"
          elsif @class_unknown
            "tw:bg-gray-500"
          else
            "tw:bg-[#cc0000]"
          end
        end

        def aria
          if @e_bike_class
            {label: translation(".class_aria", n: @e_bike_class)}
          elsif @class_unknown
            {label: translation(".class_unknown_aria")}
          else
            {hidden: true}
          end
        end

        def class_number
          tag.span(translation(".class"), class: "#{@size[:label]} tw:font-bold tw:tracking-[.12em] tw:uppercase #{@optional ? "tw:text-slate-500 tw:dark:text-slate-400" : "tw:text-[#ffd660]"}") +
            tag.span(@e_bike_class || "?", class: "#{@size[:number]} tw:mt-0.5 tw:font-header tw:font-black")
        end

        def emoto
          tag.span(translation(".emoto"), class: "#{@size[:label]} tw:font-bold tw:tracking-[.12em] tw:uppercase") +
            helpers.inline_svg_tag("icons/x.svg", class: "#{@size[:icon]} tw:mt-1 tw:p-1 tw:stroke-[2.5]", aria_hidden: true)
        end
      end
    end
  end
end
