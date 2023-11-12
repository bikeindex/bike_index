# frozen_string_literal: true

# TODO: add translations
module VehicleHelper
  def audit_frame_model_display(model_audit)
    if model_audit.unknown_model?
      content_tag(:span, "Missing model", class: "less-strong")
    else
      content_tag(:span, model_audit.frame_model)
    end
  end
end
