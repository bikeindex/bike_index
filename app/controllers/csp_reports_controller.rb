# Receives browser CSP violation reports and hands them to the forward job,
# which drops known noise and forwards the rest to Honeybadger in production.
class CspReportsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    # Browsers/bots occasionally send malformed byte sequences (e.g. overlong
    # UTF-8) that raise when Sidekiq JSON-encodes the job args, so scrub once
    # at the boundary before enqueuing.
    body = request.raw_post.dup.force_encoding(Encoding::UTF_8).scrub
    ForwardCspReportJob.perform_async(body, current_user&.id, request.user_agent)
    head :no_content
  end
end
