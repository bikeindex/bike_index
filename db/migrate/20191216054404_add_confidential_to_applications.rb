# frozen_string_literal: true

class AddConfidentialToApplications < ActiveRecord::Migration[5.0]
  def change
    add_column(
      :oauth_applications,
      :confidential,
      :boolean,
      null: false,
      default: false, # Default to false since we're using public clients
    )
  end
end
