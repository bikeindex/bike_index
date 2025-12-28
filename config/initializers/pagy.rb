# frozen_string_literal: true

# Pagy initializer file (43.x)
# See https://ddnexus.github.io/pagy/docs/api/pagy

# Pagy Options
# These options are merged with the class DEFAULT constants
Pagy.options[:limit] = 25
Pagy.options[:limit_max] = 100
Pagy.options[:max_pages] = 5000

# Overflow handling: we handle overflow in Pagy::Method override below
# to replicate the old pagy overflow: :last_page behavior

# Load the series helper for pagination component
require "pagy/toolbox/helpers/support/series"
