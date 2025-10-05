require "rails_helper"

RSpec.describe Admin::BikeStickersController, type: :request do
  base_url = "/admin/bike_stickers"

  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    let!(:bike_sticker_batch) { FactoryBot.create(:bike_sticker_batch) }
    let!(:bike_sticker) { FactoryBot.create(:bike_sticker, bike_sticker_batch: bike_sticker_batch) }
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:bike_stickers)).to eq([bike_sticker])
      expect(assigns(:bike_sticker_batches)).to eq([bike_sticker_batch])
    end
    context "with search_query" do
      it "renders" do
        get base_url, params: {search_query: "XXXXX"}
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
        expect(assigns(:bike_stickers)).to eq([])
        expect(assigns(:bike_sticker_batches)).to eq([])
      end
    end
  end

  describe "new" do
    it "renders" do
      get "#{base_url}/new"
      expect(response.status).to eq(200)
      expect(response).to render_template(:new)
    end
  end

  describe "create" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:valid_params) do
      {
        notes: "Cool new thing",
        prefix: "XX",
        initial_code_integer: "012",
        code_number_length: "05",
        stickers_to_create_count: 2,
        organization_id: organization.id
      }
    end
    before { Sidekiq::Job.clear_all }
    def expect_success(base_url, passed_params)
      expect do
        post base_url, params: {bike_sticker_batch: passed_params}
      end.to change(BikeStickerBatch, :count).by 1
      expect(flash[:error]).to be_blank
      expect(flash[:success]).to be_present

      bike_sticker_batch = BikeStickerBatch.last
      expect(bike_sticker_batch.organization_id).to eq passed_params[:organization_id]
      expect(bike_sticker_batch.user_id).to eq current_user.id
      expect(bike_sticker_batch.prefix).to eq passed_params[:prefix].strip.upcase
      if passed_params[:code_number_length].present?
        expect(bike_sticker_batch.code_number_length).to eq passed_params[:code_number_length]&.to_i
      end
      expect(response).to redirect_to(admin_bike_stickers_path(search_bike_sticker_batch_id: bike_sticker_batch.id))

      expect(CreateBikeStickerCodesJob.jobs.count).to eq 1
      target_args = [bike_sticker_batch.id,
        passed_params[:stickers_to_create_count]&.to_s,
        passed_params[:initial_code_integer]&.to_i]

      expect(CreateBikeStickerCodesJob.jobs.map { |j| j["args"] }.last.flatten).to eq target_args

      bike_sticker_batch
    end

    it "creates" do
      expect_success(base_url, valid_params)
    end
    context "with no code_number_length" do
      it "creates" do
        bike_sticker_batch = expect_success(base_url, valid_params.except(:code_number_length))
        expect(bike_sticker_batch.code_number_length).to eq 4 # Default, because number was smaller
      end
    end
    context "calculated code_number_length 5" do
      it "creates" do
        bike_sticker_batch = expect_success(base_url, valid_params.except(:code_number_length).merge(initial_code_integer: "012345"))
        expect(bike_sticker_batch.code_number_length).to eq 5
      end
    end
    context "no prefix" do
      it "fails" do
        expect do
          post base_url, params: {bike_sticker_batch: valid_params.merge(prefix: "  ")}
        end.to change(BikeStickerBatch, :count).by 0
        expect(response).to render_template(:new)
      end
    end
    context "same prefix as another batch" do
      let!(:bike_sticker_batch1) { FactoryBot.create(:bike_sticker_batch, prefix: "XX") }
      let!(:bike_sticker1) { bike_sticker_batch1.create_codes(2) }
      it "creates" do
        expect(bike_sticker_batch1.reload.max_code_integer).to eq 1
        expect_success(base_url, valid_params.merge(prefix: "xx   "))
      end
      context "higher code" do
        let!(:bike_sticker1) { bike_sticker_batch1.create_codes(1, initial_code_integer: 22) }
        it "fails" do
          expect(bike_sticker_batch1.reload.max_code_integer).to eq 22
          expect_success(base_url, valid_params.merge(stickers_to_create_count: " 02\n"))
        end
      end
      context "overlapping code" do
        let!(:bike_sticker2) { bike_sticker_batch1.create_codes(1, initial_code_integer: 12) }
        it "fails" do
          expect(bike_sticker_batch1.reload.max_code_integer).to eq 12
          expect do
            post base_url, params: {bike_sticker_batch: valid_params}
          end.to change(BikeStickerBatch, :count).by 0
          expect(response).to render_template(:new)
          bike_sticker_batch = assigns(:bike_sticker_batch)
          expect(bike_sticker_batch.errors.full_messages.join).to match("##{bike_sticker_batch1.id}")
        end
      end
    end
  end

  describe "reassign" do
    let!(:bike_sticker1) { FactoryBot.create(:bike_sticker) }
    let(:bike_sticker_batch) { FactoryBot.create(:bike_sticker_batch, code_number_length: 6, prefix: "V") }
    let(:organization) { FactoryBot.create(:organization) }
    it "doesn't do invalid things" do
      get "#{base_url}/reassign"
      expect(response.status).to eq(200)
      expect(response).to render_template(:reassign)
      expect(assigns(:bike_stickers).pluck(:id)).to match_array([bike_sticker1.id])
      expect(assigns(:valid_selection)).to be_falsey
      Sidekiq::Job.clear_all
      get "#{base_url}/reassign", params: {search_first_sticker: bike_sticker1.code,
                                           search_last_sticker: bike_sticker1.code,
                                           search_bike_sticker_batch_id: bike_sticker_batch.id,
                                           organization_id: organization.id,
                                           reassign_now: true}
      expect(AdminReassignBikeStickerCodesJob.jobs.count).to eq 0
    end
    context "valid update" do
      let!(:bike_stickers) { bike_sticker_batch.create_codes(4, initial_code_integer: 22122) }
      let(:selection_params) do
        {
          search_sticker1: "v 221 23",
          search_sticker2: "v 221 25",
          search_bike_sticker_batch_id: bike_sticker_batch.id,
          organization_id: organization.id
        }
      end
      it "updates" do
        expect(bike_sticker_batch.reload.bike_stickers.count).to eq 4
        get "#{base_url}/reassign", params: selection_params
        expect(response.status).to eq(200)
        expect(response).to render_template(:reassign)
        expect(assigns(:bike_stickers).count).to eq 3
        expect(assigns(:valid_selection)).to be_truthy
        Sidekiq::Job.clear_all
        get "#{base_url}/reassign", params: selection_params.merge(reassign_now: true)
        expect(AdminReassignBikeStickerCodesJob.jobs.count).to eq 1
        expect(BikeStickerUpdate.count).to eq 0
        expect(flash[:success]).to be_present
        AdminReassignBikeStickerCodesJob.drain
        expect(BikeStickerUpdate.count).to eq 3
        target_update_attrs = {
          organization_id: organization.id,
          user_id: current_user.id,
          kind: "admin_reassign",
          creator_kind: "creator_user",
          organization_kind: "primary_organization"
        }
        expect(BikeStickerUpdate.where(target_update_attrs).count).to eq 3
      end
    end
  end
end
