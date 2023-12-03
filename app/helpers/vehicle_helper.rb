# frozen_string_literal: true

# TODO: add translations
module VehicleHelper
  def model_audit_display(model_audit, truncate: false)
    content_tag(:strong, model_audit.mnfg_name) + "&nbsp;".html_safe +
      content_tag(:em, model_audit_frame_model_display(model_audit, truncate: truncate))
  end

  def model_audit_frame_model_display(model_audit, truncate: false)
    if model_audit.unknown_model?
      content_tag(:span, "Missing model", class: "less-strong")
    elsif truncate
      content_tag(:span, model_audit.frame_model.truncate(70), title: model_audit.frame_model)
    else
      content_tag(:span, model_audit.frame_model)
    end
  end
end
