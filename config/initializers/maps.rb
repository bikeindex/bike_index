# frozen_string_literal: true

# Self-hosted MapLibre basemap, served publicly from this host. The style.json -
# and the vector tiles (.pmtiles), glyphs and sprites it references - live in the
# maps R2 bucket. See lib/tasks/maps.rake for uploading the tiles.
MAPS_HOST = ENV.fetch("MAPS_HOST", "https://maps.bikeindex.org")
MAPS_STYLE_URL = "#{MAPS_HOST}/basemap/style.json"
# R2 bucket the tiles are uploaded to (separate and public - see maps:bucket_setup)
MAPS_BUCKET = ENV.fetch("R2_MAPS_BUCKET", "bikeindex-maps")

# The tiles object. The geography under bike-location markers changes slowly, so
# we refresh quarterly - spec/lib/tasks/maps_spec.rb re-checks the live tiles on
# the same interval.
MAPS_TILES_KEY = "basemap/tiles.pmtiles"
MAPS_TILES_URL = "#{MAPS_HOST}/#{MAPS_TILES_KEY}"
