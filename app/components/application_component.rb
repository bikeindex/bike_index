# frozen_string_literal: true

class ApplicationComponent < ViewComponent::Base
  private

  # If updating this, also update the same method in ComponentGenerator
  def stimulus_controller
    self.class.name.underscore.split("/").join("--").tr("_", "-")
  end
end
