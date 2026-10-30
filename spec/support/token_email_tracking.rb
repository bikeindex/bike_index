# frozen_string_literal: true

# Fails any spec that delivers an email with a token link Postmark would rewrite through its click
# tracker - every token link needs data-pm-no-track
module TokenEmailTracking
  TOKEN_PARAMS = %w[t token code confirmation_token b_param_token parking_notification_retrieved
    graduated_notification_remaining].freeze

  def self.delivering_email(mail)
    tracked = token_links(mail).reject { it["data-pm-no-track"] == "true" }
    raise "#{mail.tag} has a tracked token link: #{tracked.first["href"]}" if tracked.any?
  end

  def self.token_links(mail)
    Nokogiri::HTML((mail.html_part || mail).body.decoded).css("a[href]").select do |link|
      query = URI.parse(link["href"]).query
      query.present? && Rack::Utils.parse_query(query).keys.intersect?(TOKEN_PARAMS)
    rescue URI::InvalidURIError
      false
    end
  end
end

ActionMailer::Base.register_interceptor(TokenEmailTracking)
