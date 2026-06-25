# frozen_string_literal: true

# Renders Markdown into sanitized, display-safe HTML — keeps formatting tags, strips scripts/handlers.
module Markdown
  extend Functionable

  def to_safe_html(text)
    ActionController::Base.helpers.sanitize(Kramdown::Document.new(text.to_s).to_html)
  end
end
