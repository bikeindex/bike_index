# frozen_string_literal: true

# Renders autocomplete matches into hotwire_combobox option hashes, reproducing
# the formatting the search query items field used under select2.
module SearchComboboxHelper
  def combobox_option_data(matches, search_obj_name)
    matches.map do |match|
      {
        id: match["search_id"],
        value: match["search_id"],
        display: match["text"],
        content: combobox_option_content(match, search_obj_name)
      }
    end
  end

  private

  def combobox_option_content(match, search_obj_name)
    text = match["text"].to_s

    case match["category"]
    when "propulsion"
      tag.span safe_join([combobox_translation(:search_for), " ", tag.strong(text), " only"])
    when "cycle_type"
      tag.span safe_join([combobox_translation(:search_only_for), " ", tag.strong(text)])
    else
      safe_join([combobox_option_prefix(match, search_obj_name), " ", tag.span(text, class: "label")])
    end
  end

  def combobox_option_prefix(match, search_obj_name)
    case match["category"]
    when "colors"
      prefix = tag.span("#{search_obj_name} #{combobox_translation(:that_are)} ", class: "sch_")
      swatch = if match["display"].present?
        tag.span("", class: "sclr", style: "background: #{match["display"]}")
      else
        tag.span("stckrs", class: "sclr")
      end
      safe_join([prefix, swatch])
    when "cmp_mnfg", "frame_mnfg"
      tag.span("#{search_obj_name} #{combobox_translation(:made_by)}", class: "sch_")
    else
      combobox_translation(:search_for)
    end
  end

  def combobox_translation(key)
    t(key, scope: "components.search.everything_combobox")
  end
end
