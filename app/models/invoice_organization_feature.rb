# frozen_string_literal: true

# == Schema Information
#
# Table name: invoice_organization_features
#
#  id                      :integer          not null, primary key
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  invoice_id              :integer
#  organization_feature_id :integer
#
class InvoiceOrganizationFeature < ActiveRecord::Base
  belongs_to :invoice
  belongs_to :organization_feature
end
