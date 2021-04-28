# frozen_string_literal: true

# Copied from https://github.com/discourse/discourse/blob/master/config/initializers/100-oj.rb
Oj::Rails.set_encoder
Oj::Rails.set_decoder
Oj::Rails.optimize
Oj.default_options = Oj.default_options.merge(mode: :compat)

# Not sure why it's not using this by default!
MultiJson.engine = :oj
