# frozen_string_literal: true

class OrganizationFee < ActiveRecord::Base
  KIND_ENUM = { basic_feature: 0, bike_index_improvement: 1, one_off: 2 }.freeze

  enum kind: KIND_ENUM
end
