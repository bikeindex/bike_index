# == Schema Information
#
# Table name: stripe_accounts
# Database name: primary
#
#  id                  :bigint           not null, primary key
#  account_holder_type :string
#  charges_enabled     :boolean          default(FALSE), not null
#  details_submitted   :boolean          default(FALSE), not null
#  onboarded_at        :datetime
#  payouts_enabled     :boolean          default(FALSE), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_holder_id   :bigint
#  stripe_id           :string
#
# Indexes
#
#  index_stripe_accounts_on_account_holder  (account_holder_type,account_holder_id)
#  index_stripe_accounts_on_stripe_id       (stripe_id) UNIQUE
#
class StripeAccount < ApplicationRecord
  # A Connect account for someone we pay out to - a seller, or a partner shop. Not the Checkout
  # Sessions in Payment: Connect is Stripe holding the funds and carrying the money-transmission
  # licensing, so Bike Index never takes custody of a buyer's money.

  belongs_to :account_holder, polymorphic: true

  validates_presence_of :account_holder_id, :account_holder_type
  validates_uniqueness_of :stripe_id, allow_nil: true, if: :stripe_id_changed?

  scope :payable, -> { where(payouts_enabled: true) }

  class << self
    def for!(account_holder)
      find_or_create_by!(account_holder:)
    end
  end

  # Stripe's answer, not ours - somebody can finish onboarding and still not be payable
  def payable? = payouts_enabled?

  def onboarding_started? = stripe_id.present?

  def update_from_stripe!(stripe_account_obj)
    self.stripe_id ||= stripe_account_obj["id"]
    self.charges_enabled = stripe_account_obj["charges_enabled"] || false
    self.payouts_enabled = stripe_account_obj["payouts_enabled"] || false
    self.details_submitted = stripe_account_obj["details_submitted"] || false
    self.onboarded_at ||= Time.current if payouts_enabled?

    save!
    self
  end

  # Creates the Connect account if there isn't one, and returns a single-use onboarding URL.
  # Stripe's links expire, so this is called per visit rather than stored.
  def onboarding_url(refresh_url:, return_url:)
    update!(stripe_id: create_stripe_account.id) if stripe_id.blank?

    Stripe::AccountLink.create(account: stripe_id, refresh_url:, return_url:,
      type: "account_onboarding").url
  end

  private

  def create_stripe_account
    Stripe::Account.create(type: "express", metadata: {
      account_holder_type:, account_holder_id:
    })
  end
end
