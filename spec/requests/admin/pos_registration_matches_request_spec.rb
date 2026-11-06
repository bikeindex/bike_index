# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::PosRegistrationMatchesController, type: :request do
  include_context :request_spec_logged_in_as_superuser

  base_url = "/admin/pos_registration_matches"

  describe "#index" do
    let(:pos_bike) { FactoryBot.create(:bike_lightspeed_pos) }
    let(:duplicate_bike_group) { DuplicateBikeGroup.create }
    let(:owned_bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: current_user) }
    let!(:merge_candidate) { PosRegistrationMatch.create!(duplicate_bike_group:, bike: owned_bike, pos_bike:) }
    let!(:review_candidate) do
      PosRegistrationMatch.create!(duplicate_bike_group:, bike: FactoryBot.create(:bike), pos_bike:, review_reasons: %w[stolen_history impounded])
    end

    it "lists matches and filters by bucket, reason and owner" do
      expect(review_candidate.reload).to have_attributes(bucket: "review_candidate", review_reasons: %w[stolen_history impounded])

      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:collection).pluck(:id)).to match_array([merge_candidate.id, review_candidate.id])
      expect(response.body).to include("Stolen history on the serial")

      get base_url, params: {search_bucket: "merge_candidate"}
      expect(assigns(:collection).pluck(:id)).to eq([merge_candidate.id])

      get base_url, params: {search_reason: "impounded"}
      expect(assigns(:collection).pluck(:id)).to eq([review_candidate.id])

      get base_url, params: {search_reason: "not_a_reason"}
      expect(assigns(:collection).pluck(:id)).to match_array([merge_candidate.id, review_candidate.id])

      get base_url, params: {user_id: current_user.id}
      expect(assigns(:collection).pluck(:id)).to eq([merge_candidate.id])
    end
  end
end
