# Usage: ruby .claude/skills/github-pr-images/assets/inline_attachments.rb <owner/repo> <comment-id>
#
# `gh --attach` rewrites only markdown `![](path)` references; an `<img src="path">`
# keeps its local path and the upload is appended as `![<basename>](url)` instead.
# This moves each appended URL into the `src` naming that file, drops the appended
# lines, and PATCHes the comment.
require "json"
require "open3"

repo, id = ARGV
abort "usage: #{$0} <owner/repo> <comment-id>" unless repo && id

path = "repos/#{repo}/issues/comments/#{id}"
body = JSON.parse(Open3.capture2("gh", "api", path).first).fetch("body")

appended = /^!\[([^\]]+)\]\((https:\/\/github\.com\/user-attachments\/assets\/[0-9a-f-]+)\)\s*/
inlined = body.scan(appended).reduce(body.gsub(appended, "").rstrip + "\n") do |result, (name, url)|
  result.gsub(/src="(?:[^"]*\/)?#{Regexp.escape(name)}\.\w+"/, %(src="#{url}"))
end

leftover = inlined.scan(/src="(?!https?:)([^"]+)"/).flatten
abort "no upload matched: #{leftover.join(", ")}" if leftover.any?

out, status = Open3.capture2("gh", "api", "-X", "PATCH", path, "-F", "body=@-", "--jq", ".html_url", stdin_data: inlined)
abort "PATCH failed" unless status.success?
puts out
