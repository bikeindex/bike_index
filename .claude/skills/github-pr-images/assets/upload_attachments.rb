# Usage: ruby .claude/skills/github-pr-images/assets/upload_attachments.rb <body-file>
#
# Uploads each local path in an `<img src="…">` or `![alt](…)` to GitHub's
# user-attachments endpoint and rewrites the body file with the asset URLs.
require "open3"
require "uri"

body_file = ARGV.first
abort "usage: #{$0} <body-file>" unless body_file && File.file?(body_file)

CONTENT_TYPES = {".png" => "image/png", ".jpg" => "image/jpeg", ".jpeg" => "image/jpeg",
                 ".gif" => "image/gif", ".mp4" => "video/mp4", ".mov" => "video/quicktime"}.freeze
REFERENCE = /(src="|\]\()([^")]+)/

def gh(*args)
  out, status = Open3.capture2("gh", "api", *args)
  abort "gh api #{args.first} failed" unless status.success?
  out.strip
end

body = File.read(body_file)
paths = body.scan(REFERENCE).map(&:last).uniq.grep_v(/\A[a-z]+:/i)
exit if paths.empty?
missing = paths.reject { File.file?(it) }
abort "no such file: #{missing.join(", ")}" if missing.any?
unsupported = paths.reject { CONTENT_TYPES.key?(File.extname(it).downcase) }
abort "unsupported type: #{unsupported.join(", ")}" if unsupported.any?

repository_id = gh("repos/{owner}/{repo}", "--jq", ".id")
uploaded = paths.to_h do |path|
  query = URI.encode_www_form(name: File.basename(path), repository_id:,
    content_type: CONTENT_TYPES.fetch(File.extname(path).downcase))
  [path, gh("https://uploads.github.com/user-attachments/assets?#{query}", "-X", "POST",
    "-H", "Content-Type: application/octet-stream", "--input", path, "--jq", ".url")]
end

File.write(body_file, body.gsub(REFERENCE) { "#{$1}#{uploaded.fetch($2, $2)}" })
