class LockDecorator < ApplicationDecorator
  delegate_all

  def lock_type_name
    object.lock_type.name
  end
end
