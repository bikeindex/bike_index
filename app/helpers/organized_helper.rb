# frozen_string_literal: true

module OrganizedHelper
  def organized_bike_text(bike = nil)
    return nil unless bike.present?
    content_tag(:span) do
      concat(bike.frame_colors.to_sentence)
      concat(" ")
      concat(content_tag(:strong, bike.mnfg_name))
      if bike.frame_model.present?
        concat(" ")
        concat(content_tag(:em, bike.frame_model))
      end
      if bike.creation_description.present?
        concat(", ")
        concat(content_tag(:small, bike.creation_description, class: "less-strong"))
      end
    end
  end
end
