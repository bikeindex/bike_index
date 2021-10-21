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
        code_number_length: "04",
        stickers_to_create_count: 2,
        organization_id: organization.id
      }
    end
    before { Sidekiq::Worker.clear_all }
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
      expect(bike_sticker_batch.code_number_length).to eq passed_params[:code_number_length]&.to_i
      expect(response).to redirect_to(admin_bike_stickers_path(search_bike_sticker_batch_id: bike_sticker_batch.id))

      expect(CreateBikeStickerCodesWorker.jobs.count).to eq 1
      target_args = [bike_sticker_batch.id,
        passed_params[:stickers_to_create_count]&.to_s,
        passed_params[:initial_code_integer]&.to_i]

      expect(CreateBikeStickerCodesWorker.jobs.map { |j| j["args"] }.last.flatten).to eq target_args
    end

    it "creates" do
      expect_success(base_url, valid_params)
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
end
