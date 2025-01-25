# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::BannedEmailDomainsController, type: :request do
  include_context :request_spec_logged_in_as_superuser

  base_url = "/admin/banned_email_domains"

  describe "#index" do
    let!(:banned_email_domain) { FactoryBot.create(:banned_email_domain)}
    it "responds with ok" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(flash).to_not be_present
      expect(assigns(:banned_email_domains).pluck(:id)).to eq([banned_email_domain.id])
    end
  end

  describe "#new" do
    it "responds with ok" do
      get "#{base_url}/new"
      expect(response.status).to eq(200)
      expect(response).to render_template(:new)
    end
  end

  describe "#create" do
    let(:valid_attributes) { {domain: "@something.com"} }
    it "responds with ok" do
      expect do
        post base_url, params: {banned_email_domain: valid_attributes}
      end.to change(BannedEmailDomain, :count).by 1

      expect(flash[:success]).to be_present
      expect(response).to redirect_to(banned_email_domains_path)
      banned_email_domain = BannedEmailDomain.last
      expect(banned_email_domain.creator_id).to eq current_user.id
      expect(banned_email_domain.domain).to eq "@something.com"
    end

    context "with likely_new_spam_domain?" do

    end
  end
end
