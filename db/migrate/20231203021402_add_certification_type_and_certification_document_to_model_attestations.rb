class AddCertificationTypeAndCertificationDocumentToModelAttestations < ActiveRecord::Migration[6.1]
  def change
    add_column :model_attestations, :document, :string
    add_column :model_attestations, :certification_type, :string
  end
end
