require "rails_helper"

RSpec.describe Admin::InvoicesController, type: :request do
  context "given a logged-in superuser" do
    include_context :request_spec_logged_in_as_superuser

    describe "GET /admin/invoices" do
      let(:end_at) { 10.years.from_now }
      let!(:invoice) { FactoryBot.create(:invoice, subscription_start_at: 1.day.ago, subscription_end_at: end_at) }
      it "responds with 200 OK and renders the index template" do
        get "/admin/invoices"
        expect(response).to be_ok
        expect(response).to render_template(:index)
        # Do some testing of latest_period_date and time_ranges
        expect(assigns(:time_range).last).to be_within(1.day).of end_at
        expect(assigns(:invoices).pluck(:id)).to eq([invoice.id])
        get "/admin/invoices?direction=desc&period=year&render_chart=true&sort=subscription_start_at"
        expect(response).to render_template(:index)
        expect(assigns(:time_range).last).to be_within(1.day).of(Time.current)
        expect(assigns(:time_range).first).to be_within(1.day).of(1.year.ago)
        expect(assigns(:invoices).pluck(:id)).to eq([invoice.id])
        get "/admin/invoices?direction=desc&period=custom&start_time=#{1.year.ago}&sort=subscription_start_at"
        expect(response).to render_template(:index)
        expect(assigns(:time_range).last).to be_within(1.day).of(end_at)
        expect(assigns(:time_range).first).to be_within(1.day).of(1.year.ago)
        expect(assigns(:invoices).pluck(:id)).to eq([invoice.id])
        get "/admin/invoices?direction=desc&period=custom&start_time=#{1.year.ago}&end_time=#{Time.current}&sort=subscription_start_at"
        expect(response).to render_template(:index)
        expect(assigns(:time_range).last).to be_within(1.day).of(Time.current)
      end
    end
  end
end
