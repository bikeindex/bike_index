# frozen_string_literal: true

# Configure Binxtils to use Rails' configured time zone
Binxtils::TimeParser.default_time_zone = Rails.application.config.time_zone
