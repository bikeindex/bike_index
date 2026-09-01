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
  # A Stripe Connect account belonging to someone we pay out to - a seller, or a partner shop.
  #
  # Separate from the Checkout Sessions in Payment, which is us collecting for memberships.
  # Connect is the other direction: Stripe holds the marketplace funds and carries the
  # money-transmission licensing, so Bike Index never takes custody of a buyer's money.
  #
  # Nobody can be paid until Stripe says so, and they say so by webhook rather than at the end of
  # the onboarding flow - somebody can finish the form and still not be payable.

  belongs_to :account_holder, polymorphic: true

  validates_presence_of :account_holder_id, :account_holder_type
  validates_uniqueness_of :stripe_id, allow_nil: true

  scope :payable, -> { where(payouts_enabled: true) }

  class << self
    def for!(account_holder)
      find_or_create_by!(account_holder:)
    end
  end

  # The only question worth asking before releasing money
  def payable? = payouts_enabled?

  def onboarding_started? = stripe_id.present?

  # Stripe's account object, whether from a webhook or a fetch
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
