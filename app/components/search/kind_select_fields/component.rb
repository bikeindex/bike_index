# frozen_string_literal: true

module Search::KindSelectFields
  class Component < ApplicationComponent
    DEFAULT_DISTANCE = 100
    MAX_DISTANCE = 2_000 # IDK, seems reasonable

    def initialize(stolenness:, location: nil, distance: nil, is_marketplace: false)
      @is_marketplace = is_marketplace
      @distance = if distance.present?
        distance.to_i
      else
        DEFAULT_DISTANCE
      end
      @distance.clamp(1, MAX_DISTANCE)

      @location = location
      @stolenness = stolenness
    end

    private

    def api_count_url
      @is_marketplace ? "none" : "/api/v3/search/count"
    end

    def location_wrap_hidden_class
      # TODO: Show marketplace for location search too!
      return "" if @stolenness == "proximity" # if @is_marketplace

      "tw:hidden"
    end

    def include_stolenness?
      !@is_marketplace
    end

    def kind_options
      if @is_marketplace
        %w[for_sale_proximity for_sale]
      else
        # TODO: add Found, Found in search area
        %w[proximity stolen non all for_sale]
      end
    end

    def option_kind
      @is_marketplace ? :marketplace_scope : :stolenness
    end

    def opt_selected?(opt)
      opt == if @is_marketplace
        "for_sale"
      else
        @stolenness
      end
    end

    # Button only shows up on registration search
    def opt_is_button?(opt)
      opt == "for_sale" && !@is_marketplace
    end

    def opt_button_url(opt)
      if opt_is_button?(opt)
        "/marketplace"
      end
    end

    def final_radio_option(opt)
      if @is_marketplace
        kind_options.last == opt
      else
        # the button is the final option, so return 2nd to last
        kind_options[-2] == opt # 2nd to last
      end
    end

    def li_classes(opt)
      return "tw:w-full tw:md:pl-1 tw:pt-1 tw:md:pt-0" if opt_is_button?(opt)

      classes = "tw:w-full tw:has-checked:bg-gray-100 tw:has-checked:dark:bg-gray-800 tw:border tw:border-gray-200 tw:dark:border-gray-600"

      if final_radio_option(opt)
        return classes += " tw:md:rounded-r-sm tw:rounded-b-sm tw:md:rounded-bl-none"
      else
        classes += " tw:border-b-0 tw:md:border-b tw:border-r tw:md:border-r-0"
      end

      if kind_options.first == opt
        classes += " tw:md:rounded-l-sm tw:rounded-t-sm tw:md:rounded-tr-none"
      end

      classes + " tw:border-b-0 tw:md:border-b tw:md:border-r"
    end
  end
end
