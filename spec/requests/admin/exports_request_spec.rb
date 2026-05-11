require "rails_helper"

RSpec.describe Admin::ExportsController, type: :request do
  base_url = "/admin/exports"

  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    let!(:basic_export) { FactoryBot.create(:export_organization) }
    let!(:avery_export) { FactoryBot.create(:export_avery) }
    let!(:stolen_export) { FactoryBot.create(:export_organization, kind: "stolen") }
    let!(:deleted_export) { FactoryBot.create(:export_organization, deleted_at: Time.current) }
    let!(:sticker_export) { FactoryBot.create(:export_organization, options: Export.default_options("organization").merge("assign_bike_codes" => true)) }
    let!(:dated_export) { FactoryBot.create(:export_organization, options: Export.default_options("organization").merge("start_at" => Time.current.to_s)) }
    let!(:specific_export) { FactoryBot.create(:export_organization, options: Export.default_options("organization").merge("only_custom_bike_ids" => true)) }
    let!(:incomplete_export) { FactoryBot.create(:export_organization, options: Export.default_options("organization").merge("partial_registrations" => "only")) }

    it "renders with search filters" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)

      get base_url, params: {search_kind: "organization"}
      expect(assigns(:collection).pluck(:id)).to match_array([basic_export.id, avery_export.id, sticker_export.id, dated_export.id, specific_export.id, incomplete_export.id])

      get base_url, params: {search_kind: "avery"}
      expect(assigns(:collection).pluck(:id)).to eq([avery_export.id])

      get base_url, params: {search_deleted: "only"}
      expect(assigns(:collection).pluck(:id)).to eq([deleted_export.id])

      get base_url, params: {search_stickers: true}
      expect(assigns(:collection).pluck(:id)).to eq([sticker_export.id])

      get base_url, params: {search_with_dates: true}
      expect(assigns(:collection).pluck(:id)).to eq([dated_export.id])

      get base_url, params: {search_registrations: "specific"}
      expect(assigns(:collection).pluck(:id)).to eq([specific_export.id])

      get base_url, params: {search_registrations: "incomplete"}
      expect(assigns(:collection).pluck(:id)).to eq([incomplete_export.id])

      get base_url, params: {search_registrations: "registered"}
      collection_ids = assigns(:collection).pluck(:id)
      expect(collection_ids).to include(basic_export.id)
      expect(collection_ids).not_to include(specific_export.id, incomplete_export.id)
    end
  end
end
