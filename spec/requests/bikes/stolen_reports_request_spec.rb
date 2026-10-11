require "rails_helper"

RSpec.describe Bikes::StolenReportsController, type: :request do
  include_context :request_spec_logged_in_as_user_if_present
  let(:base_url) { "/bikes/#{bike.to_param}/stolen_report" }
  let(:current_user) { FactoryBot.create(:user_confirmed) }
  let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: current_user, frame_model: "Haul") }
  let(:report_params) do
    {date: "2026-10-10", time: "19:30", timezone: "America/Los_Angeles", country_id: Country.united_states_id,
     street: "Telegraph Ave & 40th St", city: "Oakland", postal_code: "94609",
     locking_description: "U-lock and cable", lock_defeat_description: "Lock was cut, and left at the scene",
     theft_description: "Cut cable on the ground", phone: "4156026066", phone_for_users: "0",
     estimated_value: "3200", proof_of_ownership: "true"}
  end

  describe "new" do
    it "renders the wizard" do
      get "#{base_url}/new"
      expect(response.status).to eq 200
      expect(response.body).to match("When and where was it stolen?")
      expect(response.body).to match("Report as stolen")
    end

    context "no current_user" do
      let(:current_user) { nil }
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }

      it "redirects" do
        get "#{base_url}/new"
        expect(response).to redirect_to bike_path(bike)
      end
    end

    context "bike already stolen" do
      let(:bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed, user: current_user) }

      it "redirects to editing the report" do
        get "#{base_url}/new"
        expect(response).to redirect_to edit_bike_stolen_report_path(bike)
      end
    end
  end

  describe "create" do
    it "marks the bike stolen" do
      expect(bike.reload.status_stolen?).to be_falsey
      Sidekiq::Job.clear_all
      post base_url, params: {stolen_record: report_params}
      expect(response).to redirect_to bike_stolen_report_path(bike)
      bike.reload
      expect(bike.status_stolen?).to be_truthy
      expect(bike.updated_by_user_at).to be_within(5).of Time.current
      stolen_record = bike.current_stolen_record
      expect(stolen_record).to have_attributes(city: "Oakland", postal_code: "94609", street: "Telegraph Ave & 40th St",
        locking_description: "U-lock and cable", theft_description: "Cut cable on the ground",
        phone_for_users: false, phone_for_shops: true, estimated_value: 3200, proof_of_ownership: true)
      expect(stolen_record.date_stolen).to eq Time.find_zone("America/Los_Angeles").parse("2026-10-10 19:30")
    end

    context "missing what happened" do
      it "re-renders on the step that asks" do
        post base_url, params: {stolen_record: report_params.merge(theft_description: " ")}
        expect(response.status).to eq 422
        expect(response.body).to match(/data-stolen-report--wizard-step-value="lock"/)
        expect(response.body).to match("Telegraph Ave &amp; 40th St")
        expect(bike.reload.status_stolen?).to be_falsey
      end
    end

    context "a date that hasn't happened yet" do
      it "re-renders on the step that asks, saying so" do
        post base_url, params: {stolen_record: report_params.merge(date: (Time.current + 10.days).to_date.iso8601)}
        expect(response.status).to eq 422
        expect(response.body).to match(/data-stolen-report--wizard-step-value="where"/)
        expect(response.body).to match("That date hasn&#39;t happened yet")
        expect(bike.reload.status_stolen?).to be_falsey
      end
    end

    context "registered to report stolen" do
      let!(:b_param) { BParam.create(origin: "register_flow", created_bike_id: bike.id, params: {"stolen_report_pending" => true}) }

      it "stops the registration sending the owner back here" do
        expect(BikeServices::Register.pending_stolen_report_bike(b_param)).to eq bike
        post base_url, params: {stolen_record: report_params}
        expect(bike.reload.status_stolen?).to be_truthy
        expect(BikeServices::Register.stolen_report_pending?(b_param.reload)).to be_falsey
      end
    end

    context "unsure of the value and the proof" do
      it "stores neither" do
        post base_url, params: {stolen_record: report_params.merge(value_unknown: "1", proof_of_ownership: "unsure")}
        expect(bike.reload.current_stolen_record).to have_attributes(estimated_value: nil, proof_of_ownership: nil)
      end
    end
  end

  describe "edit and update" do
    let(:bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed, user: current_user) }
    let(:stolen_record) { bike.current_stolen_record }

    it "renders the review, and updates" do
      get "#{base_url}/edit"
      expect(response.status).to eq 200
      expect(response.body).to match(/data-stolen-report--wizard-step-value="review"/)
      expect(response.body).to match("Save changes")

      patch base_url, params: {stolen_record: report_params.merge(police_report_number: "XX-123")}
      expect(response).to redirect_to bike_stolen_report_path(bike)
      expect(flash[:success]).to be_present
      expect(stolen_record.reload.police_report_number).to eq "XX-123"
      expect(bike.reload.current_stolen_record_id).to eq stolen_record.id
    end
  end

  describe "show" do
    let(:bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed, user: current_user) }

    it "renders next steps" do
      get base_url
      expect(response.status).to eq 200
      expect(response.body).to match("marked")
    end

    context "not stolen" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: current_user) }

      it "redirects to reporting it" do
        get base_url
        expect(response).to redirect_to new_bike_stolen_report_path(bike)
      end
    end

    context "recovered" do
      before { bike.current_stolen_record.add_recovery_information(recovered_description: "Found it") }

      it "redirects to the recovery" do
        get base_url
        expect(response).to redirect_to bike_recovered_path(bike)
        get "#{base_url}/edit"
        expect(response).to redirect_to bike_recovered_path(bike)
      end
    end
  end

  describe "photos" do
    it "stores the photo on the bike, answering with its tile" do
      expect {
        post "#{base_url}/photos", params: {photo: Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/bike.jpg"), "image/jpeg")}
      }.to change(PublicImage, :count).by 1
      expect(response.status).to eq 200
      expect(response.parsed_body["html"]).to match("Added")
      expect(bike.public_images.count).to eq 1
    end
  end

  describe "stock_photos" do
    before { stub_bikebook_catalog }

    it "renders the matches" do
      get "#{base_url}/stock_photos", params: {manufacturer: "Specialized", model: "", year: "2025"}
      expect(response.status).to eq 200
      expect(response.body).to match("stolen_report_stock_photos")
      expect(response.body).to match("bikebook.bikeindex.org/specialized/2025")
    end
  end

  describe "edit template redirects" do
    it "sends report_stolen to the wizard" do
      get "/bikes/#{bike.to_param}/edit/report_stolen"
      expect(response).to redirect_to new_bike_stolen_report_path(bike.id)
    end
  end
end
