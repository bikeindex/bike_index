require "rails_helper"

base_url = "/admin/recovery_displays"
RSpec.describe Admin::RecoveryDisplaysController, type: :request do
  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    it "renders" do
      get base_url
      expect(response).to be_ok
      expect(response).to render_template(:index)
      expect(flash).to_not be_present
    end
  end

  describe "show" do
    context "bust_cache" do
      it "busts the cache" do
        get "#{base_url}/bust_cache"
        expect(response).to redirect_to admin_recovery_displays_path
        expect(flash[:success]).to match(/cache/i)
      end
    end
  end

  describe "edit" do
    let(:recovery_display) { FactoryBot.create(:recovery_display) }
    it "renders" do
      get "#{base_url}/#{recovery_display.id}/edit"
      expect(response).to be_ok
      expect(response).to render_template(:edit)
      expect(flash).to_not be_present
    end
    it "doesn't break if the recovery_display's bike is deleted" do
      recovery_display.reload
      get "#{base_url}/#{recovery_display.id}/edit"
      expect(response).to be_ok
      expect(response).to render_template(:edit)
      expect(flash).to_not be_present
    end
  end

  describe "create" do
    context "valid create" do
      let(:valid_attrs) { {quote: "something that is nice and short and stuff"} }
      it "creates the recovery_display" do
        expect do
          post base_url, params: {recovery_display: valid_attrs}
        end.to change(RecoveryDisplay, :count).by 1

        recovery_display = RecoveryDisplay.last
        expect(recovery_display.quote).to eq valid_attrs[:quote]
      end
    end
    context "with a photo" do
      let(:file) { File.open(File.join(Rails.root, "spec", "fixtures", "bike.jpg")) }
      let(:valid_attrs) do
        {
          quote: "I recovered my bike!",
          image: Rack::Test::UploadedFile.new(file)
        }
      end
      it "creates with a photo and processes it in the background" do
        expect do
          post base_url, params: {recovery_display: valid_attrs}
        end.to change(RecoveryDisplay, :count).by 1
        Sidekiq::Worker.drain_all # Process the backgrounded image upload

        recovery_display = RecoveryDisplay.last
        expect(recovery_display.quote).to eq valid_attrs[:quote]
        expect(recovery_display.image).to be_present
        expect(recovery_display.image_processing?).to be_falsey
      end
    end
    context "invalid create" do
      let(:invalid_attrs) do
        {
          quote: "La croix scenester pug glossier, yuccie salvia humblebrag chia. Meditation health goth readymade flannel hot chicken austin tofu salvia cornhole tumeric hashtag plaid. Umami vegan hell of before they sold out copper mug chillwave authentic poke mumblecore godard la croix 8-bit. Venmo raw denim synth wolf. Food truck hot chicken waistcoat activated charcoal"
        }
      end
      it "does not create a recovery display that is too long" do
        expect {
          post base_url, params: {recovery_display: invalid_attrs}
        }.to change(RecoveryDisplay, :count).by 0
        expect(assigns(:recovery_display).errors).to be_present
      end
    end
  end
end
