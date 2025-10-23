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

  def phone_display(str)
    return "" if str.blank?

    phone_components = Phonifyer.components(str)
    number_to_phone(phone_components[:number], phone_components.except(:number))
  end

  def phone_link(phone, html_options = {})
    return "" if phone.blank?

    phone_d = phone_display(phone)
    return "" if phone_d.blank?
    # Switch extension to be pause in link
    link_to(phone_d, "tel:#{phone_d.tr("x", ";")}", html_options)
  end
end
