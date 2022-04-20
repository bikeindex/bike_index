# TODO: make this the way that superuser is defined for everyone
# e.g. if universal, update user to be superuser: true, remove superuser: true if deleted, etc
class SuperuserAbility < ApplicationRecord
  KIND_ENUM = {
    universal: 0,
    controller: 1,
    action: 2
  }.freeze

  acts_as_paranoid

  belongs_to :user

  before_validation :set_calculated_attributes

  enum kind: KIND_ENUM

  def self.kinds
    KIND_ENUM.keys.map(&:to_s)
  end

  def self.can_access?(controller_name: nil, action_name: nil)
    universal.any? || controller.where(controller_name: controller_name).any? ||
      action.where(controller_name: controller_name, action_name: action_name).any?
  end

  def set_calculated_attributes
    self.kind = calculated_kind
  end

  private

  def calculated_kind
    return "universal" if controller_name.blank?
    action_name.blank? ? "controller" : "action"
  end
end
