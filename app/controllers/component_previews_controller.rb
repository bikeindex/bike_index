# Previews render through the app's controller, so components can call the
# ControllerHelpers helper methods (display_dev_info?, current_user, ...) that
# they rely on everywhere else
class ComponentPreviewsController < ApplicationController
  include ViewComponent::PreviewActions
end
