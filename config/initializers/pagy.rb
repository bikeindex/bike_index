# frozen_string_literal: true

# Pagy initializer file (43.x)
# See https://ddnexus.github.io/pagy/docs/api/pagy

# Pagy Options
# These options are merged with the class DEFAULT constants
Pagy.options[:limit] = 25
Pagy.options[:limit_max] = 100
Pagy.options[:max_pages] = 5000

# Overflow handling: when raise_range_error is false (default), out of range pages
# return an empty page. Set to true to raise Pagy::RangeError instead.
# Pagy.options[:raise_range_error] = true

# Load the series helper for pagination component
require "pagy/toolbox/helpers/support/series"
