# frozen_string_literal: true

# General helper methods shared with View Components
module ApplicationComponentHelper
  def number_display(number)
    content_tag(:span, number_with_delimiter(number), class: ((number == 0) ? "less-less-strong" : ""))
  end

  def check_mark
    "&#x2713;".html_safe
  end

  def cross_mark
    "&#x274C;".html_safe
  end

  def search_emoji
    "🔎"
  end

  def link_emoji
    image_tag("link.svg", class: "link-emoji")
  end
end
