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

  def set_calculated_attributes
    self.kind = calculated_kind
  end

  private

  def calculated_kind
    return "universal" if controller_name.blank?
    action_name.blank? ? "controller" : "action"
  end
end
