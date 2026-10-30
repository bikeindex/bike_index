require "rails_helper"

base_url = "/admin/recoveries"
RSpec.describe Admin::RecoveriesController, type: :request do
  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    let!(:stolen_record) do
      FactoryBot.create(:stolen_record_recovered, city: "Chicago",
        region_record: FactoryBot.create(:state_illinois))
    end
    it "renders" do
      get "#{base_url}?search_recovery_display_status=all"
      expect(response).to be_ok
      expect(response).to render_template(:index)
      expect(response.body).to match("Chicago")
      expect(response.body).to match("IL")
      expect(flash).to_not be_present
      # Added in #2137 because there was an error in the scope
      get "#{base_url}?search_displayed=displayed&search_shareable=true"
      expect(response).to be_ok
      expect(response).to render_template(:index)
      expect(flash).to_not be_present
    end
  end
  describe "index with a recovery waiting on a decision" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership) }
    let!(:stolen_record) do
      FactoryBot.create(:stolen_record_recovered, bike:, can_share_recovery: true, city: "Chicago",
        recovered_description: "Got it back, thanks to Pat Smith")
    end
    before { stolen_record.update_column(:recovery_display_status, "waiting_on_decision") }
    it "renders the story, name and location to edit" do
      get base_url
      expect(response).to be_ok
      expect(response.body).to include("display[#{stolen_record.id}][quote]")
      expect(response.body).to include("Got it back, thanks to Pat Smith")
      expect(response.body).to include("display[#{stolen_record.id}][quote_by]")
      expect(response.body).to include("display[#{stolen_record.id}][location_string]")
    end
  end

  describe "bulk_update" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership) }
    let!(:stolen_record) { FactoryBot.create(:stolen_record_recovered, bike:, can_share_recovery: true, city: "Chicago") }
    let!(:stolen_record2) { FactoryBot.create(:stolen_record_recovered, bike: FactoryBot.create(:bike), can_share_recovery: true) }
    let(:sr_selected) { {stolen_record.id.to_s => stolen_record.id, stolen_record2.id.to_s => stolen_record2.id} }
    before do
      [stolen_record, stolen_record2].each do |recovery|
        recovery.update_column(:recovery_display_status, "waiting_on_decision")
      end
    end

    it "displays them with the edited text" do
      expect {
        post base_url, params: {
          sr_selected:, bulk_action: "display",
          display: {
            stolen_record.id.to_s => {quote: "Got it back, thanks!", quote_by: "Pat Smith", location_string: "Chicago, IL"},
            stolen_record2.id.to_s => {quote: "Found it", quote_by: "", location_string: ""}
          }
        }
      }.to change(RecoveryDisplay, :count).by 2
      expect(flash[:success]).to eq "2 recoveries displayed"
      recovery_display = stolen_record.reload.recovery_display
      expect(recovery_display).to have_attributes(quote: "Got it back, thanks!", quote_by: "Pat Smith", location_string: "Chicago, IL")
      expect(stolen_record.recovered_description).to eq "Awesome help by Bike Index"
      expect(stolen_record.recovery_display_status).to eq "recovery_displayed"
      expect(stolen_record2.reload.recovery_display).to have_attributes(quote: "Found it", quote_by: nil)
    end

    it "reports the ones that fail, and displays the rest" do
      expect {
        post base_url, params: {
          sr_selected:, bulk_action: "display",
          display: {
            stolen_record.id.to_s => {quote: "", quote_by: "Pat", location_string: "Chicago"},
            stolen_record2.id.to_s => {quote: "Found it", quote_by: "Sam", location_string: ""}
          }
        }
      }.to change(RecoveryDisplay, :count).by 1
      expect(response.status).to eq 422
      expect(flash[:success]).to eq "1 recovery displayed"
      expect(flash[:error]).to match(/Unable to display: ##{stolen_record.id} Quote can't be blank/)
      expect(stolen_record.reload.recovery_display).to be_blank
      # The failed row keeps what was typed, and stays checked
      expect(response.body).to include('value="Pat"')
      expect(response.body).to match(/checked="checked"[^>]*name="sr_selected\[#{stolen_record.id}\]"|name="sr_selected\[#{stolen_record.id}\]"[^>]*checked="checked"/)
      # Its sort, filter and pagination links lead back to the index
      expect(response.body).to include('href="/admin/recoveries?')
      expect(response.body).not_to include("recoveries/bulk_update")
    end

    it "doesn't flash a success when none are displayed" do
      post base_url, params: {
        sr_selected: {stolen_record.id.to_s => stolen_record.id}, bulk_action: "display",
        display: {stolen_record.id.to_s => {quote: ""}}
      }
      expect(flash[:success]).to be_blank
      expect(flash[:error]).to be_present
    end

    context "already displayed" do
      before { FactoryBot.create(:recovery_display, stolen_record:) }
      it "doesn't display it again" do
        stolen_record.update_column(:recovery_display_status, "waiting_on_decision")
        expect {
          post base_url, params: {sr_selected:, bulk_action: "display", display: {stolen_record2.id.to_s => {quote: "Found it"}}}
        }.to change(RecoveryDisplay, :count).by 1
        expect(flash[:error]).to match(/##{stolen_record.id} is already displayed/)
        post base_url, params: {sr_selected:, bulk_action: "not_displayed"}
        expect(flash[:success]).to be_blank
        expect(flash[:error]).to eq "Unable to mark not displayable: ##{stolen_record.id} is already displayed"
        expect(stolen_record.reload.recovery_display_status).not_to eq "not_displayed"
      end
    end

    it "marks them not displayable" do
      expect {
        post base_url, params: {sr_selected:, bulk_action: "not_displayed"}
      }.to change(RecoveryDisplay, :count).by 0
      expect(flash[:success]).to eq "2 recoveries marked not displayable"
      expect([stolen_record, stolen_record2].map { it.reload.recovery_display_status }).to eq(%w[not_displayed not_displayed])
    end

    context "with a hidden bike" do
      before { bike.update(user_hidden: true) }
      it "marks it not displayable, but doesn't display it" do
        post base_url, params: {sr_selected: {stolen_record.id.to_s => stolen_record.id}, bulk_action: "display"}
        expect(flash[:error]).to eq "Unable to display: ##{stolen_record.id} bike is hidden"
        expect(RecoveryDisplay.count).to eq 0
        post base_url, params: {sr_selected: {stolen_record.id.to_s => stolen_record.id}, bulk_action: "not_displayed"}
        expect(flash[:success]).to eq "1 recovery marked not displayable"
        expect(stolen_record.reload.recovery_display_status).to eq "not_displayed"
      end
    end

    context "recovery not waiting on a decision" do
      before { stolen_record.update(recovery_display_status: "not_displayed") }
      it "leaves it alone" do
        post base_url, params: {sr_selected: {stolen_record.id.to_s => stolen_record.id}, bulk_action: "display"}
        expect(flash[:error]).to be_present
        expect(RecoveryDisplay.count).to eq 0
      end
    end

    context "unknown action" do
      it "flashes an error" do
        post base_url, params: {sr_selected:, bulk_action: "destroy_all"}
        expect(flash[:error]).to eq "Unknown action!"
        expect(RecoveryDisplay.count).to eq 0
      end
    end

    context "with only the recoveries update ability" do
      let(:current_user) { FactoryBot.create(:user_confirmed) }
      let!(:superuser_ability) { SuperuserAbility.create(user: current_user, controller_name: "recoveries", action_name: "update") }
      it "marks not displayable, but doesn't display" do
        post base_url, params: {sr_selected:, bulk_action: "display"}
        expect(flash[:error]).to match(/administrator/)
        expect(RecoveryDisplay.count).to eq 0
        post base_url, params: {sr_selected:, bulk_action: "not_displayed"}
        expect(flash[:success]).to eq "2 recoveries marked not displayable"
      end
    end
  end

  describe "edit" do
    let(:stolen_record) { bike.current_stolen_record }
    let(:bike) { FactoryBot.create(:bike, :with_stolen_record, :with_ownership) }
    it "doesn't break if recovery's bike is deleted" do
      expect(stolen_record).to be_present
      bike.destroy
      get "#{base_url}/#{stolen_record.id}/edit"
      expect(response).to be_ok
      expect(flash).to_not be_present
    end
  end
  describe "update" do
    context "admin marks recovery as undisplayable" do
      let(:stolen_record) { FactoryBot.create(:stolen_record, can_share_recovery: true, recovery_display_status: "waiting_on_decision") }
      let(:params) { {id: stolen_record.id, stolen_record: {is_not_displayable: true}} }
      it "updates waiting_on_decision to not_displayed" do
        expect {
          put "#{base_url}/#{stolen_record.id}", params: params
        }.to change(RecoveryDisplay, :count).by 0
        stolen_record.reload
        expect(stolen_record.recovery_display_status).to eq "not_displayed"
        expect(response).to redirect_to(admin_recoveries_path)
        expect(flash).to be_present
      end
      context "bike deleted" do
        it "updates waiting_on_decision to not_displayed" do
          stolen_record.bike.update(user_hidden: true)
          expect {
            put "#{base_url}/#{stolen_record.id}", params: params
          }.to change(RecoveryDisplay, :count).by 0
          stolen_record.reload
          expect(stolen_record.recovery_display_status).to eq "not_displayed"
          expect(response).to redirect_to(admin_recoveries_path)
          expect(flash).to be_present
        end
      end
    end
    context "admin marks recovery as can_share_recovery" do
      let(:stolen_record) { FactoryBot.create(:stolen_record, can_share_recovery: true, recovery_display_status: "not_eligible") }
      let(:params) { {id: stolen_record.id, stolen_record: {can_share_recovery: true}} }
      it "updates can_share_recovery" do
        expect {
          put "#{base_url}/#{stolen_record.id}", params: params
        }.to change(RecoveryDisplay, :count).by 0
        stolen_record.reload
        expect(stolen_record.can_share_recovery).to be_truthy
        expect(response).to redirect_to(admin_recoveries_path)
        expect(flash).to be_present
      end
    end
    context "admin marks recovery as index_helped_recover" do
      let(:stolen_record) { FactoryBot.create(:stolen_record, can_share_recovery: true, recovery_display_status: "not_eligible") }
      let(:params) { {id: stolen_record.id, stolen_record: {index_helped_recovery: true}} }
      it "updates index_helped_recover" do
        expect {
          put "#{base_url}/#{stolen_record.id}", params: params
        }.to change(RecoveryDisplay, :count).by 0
        stolen_record.reload
        expect(stolen_record.index_helped_recovery).to be_truthy
        expect(response).to redirect_to(admin_recoveries_path)
        expect(flash).to be_present
      end
    end
    context "admin marks undisplayable bike as displayable" do
      let!(:public_image) { FactoryBot.create(:public_image, imageable: bike) }
      let(:stolen_record) { FactoryBot.create(:stolen_record, can_share_recovery: true, recovery_display_status: "not_displayed") }
      let(:bike) { stolen_record.bike }
      let(:params) { {id: stolen_record.id, stolen_record: {mark_as_eligible: true}} }
      it "updates not_displayed to waiting_on_decision" do
        bike.reload.update(updated_at: Time.current)
        stolen_record.reload.update(updated_at: Time.current)
        expect {
          put "#{base_url}/#{stolen_record.id}", params: params
        }.to change(RecoveryDisplay, :count).by 0
        stolen_record.reload
        expect(stolen_record.recovery_display_status).to eq "waiting_on_decision"
        expect(response).to redirect_to(new_admin_recovery_display_path(stolen_record))
        expect(flash).to be_present
      end
    end
  end
end
