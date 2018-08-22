# frozen_string_literal: true

class PaidFeature < ActiveRecord::Base
  KIND_ENUM = { basic_feature: 0, bike_index_improvement: 1, one_off: 2 }.freeze

  has_many :invoice_paid_features
  has_many :invoices, through: :invoice_paid_features

  enum kind: KIND_ENUM
end
