# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::EmailDomainsController, type: :request do
  include_context :request_spec_logged_in_as_superuser

  base_url = "/admin/banned_email_domains"

  describe "#index" do
    let!(:banned_email_domain) { FactoryBot.create(:banned_email_domain) }
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
    let(:valid_attributes) { {domain: "@rustymails.com"} }

    it "responds with not likely spam" do
      expect do
        post base_url, params: {banned_email_domain: valid_attributes}
      end.to change(EmailDomain, :count).by 0

      expect(flash[:error]).to be_present
      expect(response).to render_template(:new)
    end

    context "with over required user count" do
      let!(:user) { FactoryBot.create(:user_confirmed, email: "fff@rustymails.com") }
      before { stub_const("EmailDomain::EMAIL_MIN_COUNT", 0) }

      it "creates" do
        expect do
          post base_url, params: {banned_email_domain: valid_attributes}
        end.to change(EmailDomain, :count).by 1

        expect(flash[:success]).to be_present
        expect(response).to redirect_to(admin_banned_email_domains_path)
        banned_email_domain = EmailDomain.last
        expect(banned_email_domain.creator_id).to eq current_user.id
        expect(banned_email_domain.domain).to eq "@rustymails.com"
      end

      context "with more bikes created" do
        let!(:bike1) { FactoryBot.create(:bike, owner_email: "fff@rustymails.com") }
        let!(:bike2) { FactoryBot.create(:bike, owner_email: "ffg@rustymails.com") }
        let!(:bike3) { FactoryBot.create(:bike, owner_email: "ffh@rustymails.com") }

        it "responds with not likely spam" do
          expect do
            post base_url, params: {banned_email_domain: valid_attributes}
          end.to change(EmailDomain, :count).by 0

          expect(flash[:error]).to be_present
          expect(response).to render_template(:new)
        end
      end
    end
  end

  describe "destroy" do
    let!(:banned_email_domain) { FactoryBot.create(:banned_email_domain, domain: "gmail.com") }
    it "soft deletes" do
      expect do
        delete "#{base_url}/#{banned_email_domain.id}"
      end.to change(EmailDomain, :count).by(-1)

      expect(flash[:success]).to be_present
      expect(EmailDomain.unscoped.where(id: banned_email_domain.id).count).to eq 1
    end
  end
end
