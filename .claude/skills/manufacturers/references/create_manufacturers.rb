#!/usr/bin/env ruby
# frozen_string_literal: true

# Takes JSON rather than key=value args so no value passes through a shell, which can merge them into `name`

require "erb"
require "json"
require "net/http"
require "open3"

ADMIN_DATA = File.expand_path("../../admin-data-api/scripts/admin_data.rb", __dir__)
KEYS = %w[name website frame_maker motorized_only total_years_active notes open_year close_year
  description twitter_name].freeze

manufacturers = JSON.parse(ARGF.read)
abort("expected a JSON array of manufacturers") unless manufacturers.is_a?(Array)
manufacturers.each do |manufacturer|
  unknown = manufacturer.keys - KEYS
  abort("unknown keys #{unknown} in #{manufacturer}") if unknown.any?
  abort("missing name in #{manufacturer}") if manufacturer["name"].to_s.strip.empty?
end

manufacturers.each do |manufacturer|
  name = manufacturer["name"]
  existing = Net::HTTP.get_response(URI("https://bikeindex.org/api/v3/manufacturers/#{ERB::Util.url_encode(name)}"))
  if existing.code == "200"
    puts "#{name}: already exists — #{JSON.parse(existing.body).dig("manufacturer", "slug")}, skipped"
    next
  end

  output, errors, status = Open3.capture3(ADMIN_DATA, "create-manufacturer", *manufacturer.map { |key, value| "#{key}=#{value}" })
  abort("#{name}: create failed\n#{errors}#{output}") unless status.success?

  created = JSON.parse(output)["manufacturer"]
  puts "#{name}: created — https://bikeindex.org/admin/manufacturers/#{created["slug"]}"
end
