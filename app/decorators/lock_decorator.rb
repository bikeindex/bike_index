# NB: Decorators are deprecated in this project.
#     Use Helper methods for view logic, consider incrementally refactoring
#     existing view logic from decorators to view helpers.
class LockDecorator < ApplicationDecorator
  delegate_all

  def lock_type_name
    object.lock_type.name
  end
end
