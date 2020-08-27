class OperateLineCustomerSerializer < ApplicationSerializer
  attributes :id,
    :name,
    :status,
    :status_humanized,
    :appointment_at,
    :line_number

  def appointment_at
    object.appointment_at&.to_i
  end
end
