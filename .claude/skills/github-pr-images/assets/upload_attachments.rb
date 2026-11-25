# Usage: ruby .claude/skills/github-pr-images/assets/upload_attachments.rb <body-file>
#
# Uploads every local file the body references - `<img src="tmp/x.png">` or
# `![alt](tmp/x.png)` - to GitHub's user-attachments endpoint, the one
# `gh … --attach` uses, and rewrites the body file in place with the asset URLs.
# Paths resolve against the repo root. Nothing is posted: the body is the caller's
# to POST or PATCH.
require "json"
require "open3"
require "uri"

body_file = ARGV.first
abort "usage: #{$0} <body-file>" unless body_file && File.file?(body_file)

def gh(*args)
  out, status = Open3.capture2("gh", "api", *args)
  abort "gh api #{args.first} failed" unless status.success?
  out.strip
end

CONTENT_TYPES = {".png" => "image/png", ".jpg" => "image/jpeg", ".jpeg" => "image/jpeg",
                 ".gif" => "image/gif", ".mp4" => "video/mp4", ".mov" => "video/quicktime"}.freeze

body = File.read(body_file)
paths = body.scan(/src="([^"]+)"|\]\(([^)\s]+)\)/).flatten.compact.uniq.grep_v(/\A[a-z]+:/i)
missing = paths.reject { File.file?(_1) }
abort "no such file: #{missing.join(", ")}" if missing.any?

repository_id = gh("repos/{owner}/{repo}", "--jq", ".id")
uploaded = paths.to_h do |path|
  query = URI.encode_www_form(name: File.basename(path), repository_id:,
    content_type: CONTENT_TYPES.fetch(File.extname(path).downcase) { abort "unsupported type: #{path}" })
  [path, gh("-X", "POST", "https://uploads.github.com/user-attachments/assets?#{query}",
    "-H", "Content-Type: application/octet-stream", "--input", path, "--jq", ".url")]
end

File.write(body_file, uploaded.reduce(body) { |result, (path, url)| result.gsub(/(?<=src="|\]\()#{Regexp.escape(path)}(?=[")])/, url) })
uploaded.each { |path, url| puts "#{path} #{url}" }
