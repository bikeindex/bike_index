# == Schema Information
#
# Table name: superuser_abilities
#
#  id              :bigint           not null, primary key
#  action_name     :string
#  controller_name :string
#  deleted_at      :datetime
#  kind            :integer          default("universal")
#  su_options      :jsonb
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  user_id         :bigint
#
# Indexes
#
#  index_superuser_abilities_on_user_id  (user_id)
#

# TODO: make this the way that superuser is defined for everyone
# e.g. if universal, update user to be superuser: true, remove superuser: true if deleted, etc
class SuperuserAbility < ApplicationRecord
  KIND_ENUM = {
    universal: 0,
    controller: 1,
    action: 2
  }.freeze

  SU_OPTIONS = [
    :no_always_show_credibility,
    :no_hide_spam
  ].freeze

  # These are the default - because they're empty
  SU_INVERSE_OPTIONS = {
    always_show_credibility: :no_always_show_credibility,
    hide_spam: :no_hide_spam
  }.freeze

  acts_as_paranoid

  belongs_to :user

  before_validation :set_calculated_attributes

  enum :kind, KIND_ENUM

  scope :non_universal, -> { where.not(kind: "universal") }

  def self.kinds
    KIND_ENUM.keys.map(&:to_s)
  end

  def self.can_access?(controller_name: nil, action_name: nil)
    return true if universal.any? || controller.where(controller_name: controller_name).any?
    return false if action_name.blank?
    # if permitted to view edit, also permitted to view show (lazy hack because there aren't RBAC roles)
    action_name = %w[show edit] if action_name == "show"
    action.where(controller_name: controller_name).where(action_name: action_name).any?
  end

  def self.su_inverse_option?(option)
    SU_INVERSE_OPTIONS.key?(option.to_sym)
  end

  def self.su_inverse_option(option)
    SU_INVERSE_OPTIONS[option.to_sym]
  end

  def self.with_su_option(option)
    inverse = su_inverse_option(option)
    if inverse
      where.not("su_options ?& array[:keys]", keys: [inverse.to_s])
    else
      where("su_options ?& array[:keys]", keys: [option.to_s])
    end
  end

  def su_option?(option)
    inverse_option = self.class.su_inverse_option(option)
    if inverse_option
      su_options.exclude?(inverse_option.to_s)
    else
      su_options.include?(option.to_s)
    end
  end

  def set_calculated_attributes
    self.kind = calculated_kind
    self.su_options ||= []
    self.su_options = su_options.sort
  end

  private

  def calculated_kind
    return "universal" if controller_name.blank?
    action_name.blank? ? "controller" : "action"
  end
end
