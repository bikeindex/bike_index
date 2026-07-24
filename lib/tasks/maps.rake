# frozen_string_literal: true

# Streams the Protomaps basemap (a single .pmtiles file) straight from a remote
# URL into the maps R2 bucket, served publicly from MAPS_HOST. The file never
# touches local disk - it is piped through a multipart upload - but the whole
# download runs over this machine's connection, so the task confirms first.
#
#   bundle exec rails "maps:upload_basemap[https://build.protomaps.com/<date>.pmtiles]"
#
# Refresh the tiles quarterly (see MAPS_TILES_MAX_AGE); Cloudflare caches the
# object, so purge MAPS_HOST after replacing it.
#
# One-time R2 + Cloudflare setup (dashboard), before the first upload:
#
#   Bucket:       bikeindex-maps  (keep SEPARATE from the uploads bucket - this one is public)
#   Public host:  https://maps.bikeindex.org  (R2 custom domain, never the S3 endpoint)
#   Tiles object: basemap/tiles.pmtiles  ->  https://maps.bikeindex.org/basemap/tiles.pmtiles
#
#   1. Create the R2 bucket "bikeindex-maps". It holds only the public basemap
#      (tiles, style.json, glyphs, sprites under basemap/) - no user data, no secrets.
#   2. Connect the custom domain maps.bikeindex.org to the bucket and serve all
#      reads from it. Do not expose the raw S3 endpoint.
#   3. CORS: allow GET, HEAD and Range from any origin (AllowedOrigins ["*"]). The
#      tiles are public OSM data and CORS won't stop non-browser abuse anyway -
#      rate limiting and caching (below) are what cap abuse, not CORS. "*" also
#      keeps dev/staging config-free.
#   4. Cache Rule on maps.bikeindex.org: cache and respect the object's
#      Cache-Control (the upload sets max-age). Edge caching keeps R2 read ops - and
#      the bill - low.
#   5. Rate-limit maps.bikeindex.org per IP to cap abuse (R2 egress is free, ops are not).
#   6. Create an R2 API token scoped to ONLY "bikeindex-maps" (Object Read & Write)
#      and set R2_MAPS_ENDPOINT, R2_MAPS_ACCESS_KEY, R2_MAPS_ACCESS_KEY_SECRET
#      (R2_MAPS_BUCKET defaults to bikeindex-maps).
#   7. Upload the style.json, glyphs and sprites under basemap/ too (see MAPS_STYLE_URL).
namespace :maps do
  desc "Stream a remote .pmtiles basemap into the maps R2 bucket"
  task :upload_basemap, [:source, :key] => :environment do |_task, args|
    require "aws-sdk-s3"
    require "net/http"

    part_size = 32 * 1024 * 1024 # multipart chunk held in memory at a time

    source = args[:source].presence || ENV["MAPS_SOURCE_URL"]
    abort "Usage: rails 'maps:upload_basemap[https://build.protomaps.com/<date>.pmtiles]'" if source.blank?

    missing = %w[R2_MAPS_ENDPOINT R2_MAPS_ACCESS_KEY R2_MAPS_ACCESS_KEY_SECRET].reject { |name| ENV[name].present? }
    abort "Missing #{missing.join(", ")} - see the one-time R2 setup at the top of #{__FILE__}." if missing.any?

    key = args[:key].presence || MAPS_TILES_KEY
    bucket = MAPS_BUCKET
    uri = URI.parse(source)

    length = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { |http| http.head(uri.request_uri)["content-length"] }
    size = length ? "#{(length.to_f / (1024**3)).round(1)}GB" : "~100GB"

    warn "⚠️  About to stream #{size} from #{source} through your current connection into #{bucket}/#{key}."
    warn "    Both the download and the re-upload run over this network - it will take a while and use that bandwidth."
    print "Continue? [y/N] "
    abort "Aborted." unless $stdin.gets&.strip&.downcase&.start_with?("y")

    client = Aws::S3::Client.new(
      endpoint: ENV.fetch("R2_MAPS_ENDPOINT"),
      access_key_id: ENV.fetch("R2_MAPS_ACCESS_KEY"),
      secret_access_key: ENV.fetch("R2_MAPS_ACCESS_KEY_SECRET"),
      region: "auto"
    )

    upload_id = client.create_multipart_upload(bucket:, key:,
      content_type: "application/octet-stream", cache_control: "public, max-age=86400").upload_id
    parts = []
    buffer = "".b

    begin
      # R2 (unlike S3) requires every part but the last to be the same size, so
      # upload exactly part_size bytes at a time and keep the remainder buffered.
      flush = proc do |body|
        number = parts.size + 1
        result = client.upload_part(bucket:, key:, upload_id:, part_number: number, body:)
        parts << {etag: result.etag, part_number: number}
        print "\rUploaded #{parts.size} parts"
      end

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(Net::HTTP::Get.new(uri)) do |response|
          response.value
          response.read_body do |chunk|
            buffer << chunk
            flush.call(buffer.slice!(0, part_size)) while buffer.bytesize >= part_size
          end
        end
      end
      flush.call(buffer) unless buffer.empty?
      client.complete_multipart_upload(bucket:, key:, upload_id:, multipart_upload: {parts:})
    rescue
      client.abort_multipart_upload(bucket:, key:, upload_id:)
      raise
    end

    puts "\nDone: #{MAPS_HOST}/#{key}"
    puts "Purge the Cloudflare cache for #{MAPS_HOST} so clients fetch the new tiles."
  end
end
