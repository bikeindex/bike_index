#!/usr/bin/env ruby
# frozen_string_literal: true

# Creates each manufacturer in a JSON array, from a file or stdin:
#   [{"name": "Vetra", "website": "https://vetrapowersports.com", "frame_maker": true, "motorized_only": true}]
# Skips a name the public API already finds, and stops at the first one that fails or comes back
# with a different name — the values never pass through a shell, so nothing gets word-split into `name`.

require "erb"
require "json"
require "net/http"
require "open3"

ADMIN_DATA = File.expand_path("../../admin-data-api/scripts/admin_data.rb", __dir__)
KEYS = %w[name website frame_maker motorized_only total_years_active notes open_year close_year
  description twitter_name].freeze

manufacturers = JSON.parse(ARGF.read)
abort("expected a JSON array of manufacturers") unless manufacturers.is_a?(Array) && manufacturers.any?
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
  abort("#{name}: created as #{created["name"].inspect} (id #{created["id"]}) — fix it in admin") if created["name"] != name
  abort("#{name}: created without a website (id #{created["id"]}) — fix it in admin") if manufacturer["website"] && !created["website"]
  puts "#{name}: created — https://bikeindex.org/admin/manufacturers/#{created["slug"]}"
end
