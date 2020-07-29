# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::ExchangeRatesController, type: :request do
  include_context :request_spec_logged_in_as_superuser

  def base_url(path = nil)
    "/admin/exchange_rates/#{path}"
  end

  describe "#index" do
    it "responds with ok" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(flash).to_not be_present
    end
  end

  describe "#new" do
    it "responds with ok" do
      get base_url("new")
      expect(response.status).to eq(200)
      expect(response).to render_template(:new)
    end
  end

  describe "#create" do
    it "responds with ok" do
      attrs = FactoryBot.attributes_for(:exchange_rate)

      post base_url, params: {exchange_rate: attrs}

      expect(flash[:error]).to be_blank
      expect(response).to redirect_to(admin_exchange_rates_url)
    end
  end

  describe "#edit" do
    it "responds with ok" do
      xrate = FactoryBot.create(:exchange_rate)

      get base_url("#{xrate.id}/edit")

      expect(response.status).to eq(200)
      expect(response).to render_template(:edit)
      expect(flash).to_not be_present
    end
  end

  describe "#update" do
    it "responds with ok" do
      xrate = FactoryBot.create(:exchange_rate)
      new_rate = 1.53
      expect(xrate.rate).to_not eq(new_rate)

      patch base_url(xrate.id), params: {
        exchange_rate: {rate: new_rate}
      }

      expect(flash[:error]).to be_blank
      expect(response).to redirect_to(admin_exchange_rates_url)
      expect(xrate.reload.rate).to eq(new_rate)
    end
  end

  describe "#destroy" do
    it "responds with ok" do
      xrate = FactoryBot.create(:exchange_rate)
      expect(ExchangeRate.count).to eq(1)

      delete base_url(xrate.id)

      expect(response).to redirect_to(admin_exchange_rates_url)
      expect(ExchangeRate.count).to be_zero
    end
  end
end
