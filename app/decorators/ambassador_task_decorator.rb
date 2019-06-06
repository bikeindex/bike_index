# NB: Decorators are deprecated in this project.
#     Use Helper methods for view logic, consider incrementally refactoring
#     existing view logic from decorators to view helpers.
class AmbassadorTaskDecorator < ApplicationDecorator
  delegate_all

  def button_to_toggle_completion_status(*); end
end
