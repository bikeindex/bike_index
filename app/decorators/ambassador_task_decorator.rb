class AmbassadorTaskDecorator < ApplicationDecorator
  delegate_all
  alias ambassador_task_assignment object

  def button_to_toggle_completion_status(*); end
end
