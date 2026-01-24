# frozen_string_literal: true

# General helper methods shared with View Components
module ApplicationComponentHelper
  def number_display(number)
    content_tag(:span, number_with_delimiter(number), class: ((number == 0) ? "less-less-strong" : ""))
  end

  # currency_name_suffix options: [false, true, :if_not_default]
  def amount_display(obj, currency_name_suffix: false)
    return if obj.amount_cents.nil?

    content_tag(:span) do
      concat(content_tag(:span, obj.currency_symbol, title: obj.currency_name))
      concat(number_display(obj.amount))
      if render_currency_name?(currency_name_suffix, obj.currency_name)
        # Uses 66% so that it works for different size text
        concat(content_tag(:span, " #{obj.currency_name}", class: "tw:text-[66%]"))
      end
    end
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

  private

  def render_currency_name?(currency_name_suffix, currency_name)
    return true if currency_name_suffix == true
    return false if currency_name_suffix != :if_not_default

    (current_currency || Currency.default).name != currency_name
  end
end
