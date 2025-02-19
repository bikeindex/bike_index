# frozen_string_literal: true

class User::CreateOrUpdateMembershipFromPaymentJob < ApplicationJob
  def perform(payment_id, admin_id = nil)
    payment = Payment.find(payment_id)
    return if payment.membership_id.present?

    membership = Membership.where(user_id: payment.user_id).time_ordered.active.last
    if membership.present?
      membership.update!(period_from_amount(payment.amount_cents, start_at: membership.start_at,
        end_at: membership.end_at))
    else
      membership = Membership.new(user_id: payment.user_id, creator_id: admin_id)
      membership.kind = kind_from_amount(payment.amount_cents)
      membership.update!(period_from_amount(payment.amount_cents))
    end
    payment.update!(membership_id: membership.id)
  end

  private

  # for simplicity, just do basic and patron - plus is just for extra gifts
  def kind_from_amount(amount_cents)
    amount_cents < 5000 ? "basic" : "patron"
  end

  def period_from_amount(amount_cents, start_at: nil, end_at: nil)
    start_at ||= Time.current
    end_at ||= start_at

    extension = if amount_cents < 999
      1.month
    elsif amount_cents < 2500
      3.months
    elsif amount_cents < 4999
      6.months
    else
      1.year
    end

    { start_at:, end_at: end_at + extension }
  end
end
