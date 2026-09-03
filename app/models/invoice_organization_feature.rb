# frozen_string_literal: true

# == Schema Information
#
# Table name: invoice_organization_features
# Database name: primary
#
#  id                      :integer          not null, primary key
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  invoice_id              :integer
#  organization_feature_id :integer
#
# Indexes
#
#  index_invoice_organization_features_on_invoice_id               (invoice_id)
#  index_invoice_organization_features_on_organization_feature_id  (organization_feature_id)
#
class InvoiceOrganizationFeature < ActiveRecord::Base
  belongs_to :invoice
  belongs_to :organization_feature
end
