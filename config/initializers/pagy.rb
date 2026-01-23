# frozen_string_literal: true

# Pagy initializer file (43.x)
# See https://ddnexus.github.io/pagy/docs/api/pagy

# Pagy Options
# These options are merged with the class DEFAULT constants
Pagy.options[:limit] = 25
Pagy.options[:limit_max] = 100
Pagy.options[:max_pages] = 5000
Pagy::DEFAULT[:max_per_page] = 100

# Raise RangeError for out-of-range pages so we can redirect to last valid page
# (handled in ApplicationController via rescue_from)
Pagy.options[:raise_range_error] = true

# Load the series helper for pagination component
require "pagy/toolbox/helpers/support/series"
