# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::EmailDomainsController, type: :request do
  include_context :request_spec_logged_in_as_superuser

  base_url = "/admin/email_domains"

  describe "#index" do
    let!(:email_domain) { FactoryBot.create(:email_domain) }
    it "responds with ok" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(flash).to_not be_present
      expect(assigns(:email_domains).pluck(:id)).to eq([email_domain.id])
    end
  end

  describe "#new" do
    it "responds with ok" do
      get "#{base_url}/new"
      expect(response.status).to eq(200)
      expect(response).to render_template(:new)
    end
  end

  describe "#show" do
    let(:email_domain) { FactoryBot.create(:email_domain) }
    it "responds with ok" do
      get "#{base_url}/#{email_domain.to_param}"
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
      expect(assigns(:email_domain)&.id).to eq email_domain.id
    end
  end

  describe "#create" do
    let(:valid_attributes) { {domain: "@rustymails.com", status:} }
    let(:status) { "permitted" }

    it "creates" do
      expect do
        post base_url, params: {email_domain: valid_attributes}
      end.to change(EmailDomain, :count).by 1

      expect(flash[:success]).to be_present
      email_domain = EmailDomain.last
      expect(email_domain).to have_attributes(domain: "@rustymails.com", status:)
      expect(email_domain.no_auto_assign_status?).to be_falsey
    end

    context "status: banned" do
      let(:status) { "banned" }
      it "responds with not likely spam" do
        expect do
          post base_url, params: {email_domain: valid_attributes}
        end.to change(EmailDomain, :count).by 0

        expect(flash[:error]).to be_present
        expect(response).to render_template(:new)
      end

      context "with over required user count" do
        let!(:user) { FactoryBot.create(:user_confirmed, email: "fff@rustymails.com") }
        before { stub_const("EmailDomain::EMAIL_MIN_COUNT", 0) }

        it "creates" do
          expect do
            post base_url, params: {email_domain: valid_attributes}
          end.to change(EmailDomain, :count).by 1

          expect(flash[:success]).to be_present
          expect(response).to redirect_to(admin_email_domains_path)
          email_domain = EmailDomain.last
          expect(email_domain.creator_id).to eq current_user.id
          expect(email_domain.domain).to eq "@rustymails.com"
        end

        context "with more bikes created" do
          let!(:bike1) { FactoryBot.create(:bike, owner_email: "fff@rustymails.com") }
          let!(:bike2) { FactoryBot.create(:bike, owner_email: "ffg@rustymails.com") }
          let!(:bike3) { FactoryBot.create(:bike, owner_email: "ffh@rustymails.com") }

          it "responds with not likely spam" do
            expect do
              post base_url, params: {email_domain: valid_attributes}
            end.to change(EmailDomain, :count).by 0

            expect(flash[:error]).to be_present
            expect(response).to render_template(:new)
          end
        end
      end
    end
  end

  describe "#update" do
    let!(:email_domain) { FactoryBot.create(:email_domain, domain: "mails.com", status:, created_at: 1.week.ago) }
    let(:status) { "banned" }

    it "updates" do
      email_domain.update(status_changed_at: 1.week.ago)
      expect(email_domain.reload.status_changed_at).to be < Time.current - 1.day
      expect(email_domain.status_changed_after_create?).to be_falsey

      patch "#{base_url}/#{email_domain.id}", params: {
        email_domain: {domain: "newdomain.com", status: "ban_pending"}
      }
      expect(flash[:success]).to be_present
      expect(email_domain.reload.status).to eq "ban_pending"
      expect(email_domain.domain).to eq "mails.com"
      expect(email_domain.status_changed_at).to be_within(1).of Time.current
      expect(email_domain.status_changed_after_create?).to be_truthy
      expect(email_domain.no_auto_assign_status?).to be_truthy
    end

    context "switching to banned" do
      let(:status) { "permitted" }

      it "responds with not likely spam" do
        patch "#{base_url}/#{email_domain.id}", params: {email_domain: {status: "banned"}}

        expect(flash[:error]).to be_present
        expect(flash[:error]).to_not match("bikes")
        expect(email_domain.reload.status).to eq "permitted"
      end

      context "with over required user count" do
        let!(:user) { FactoryBot.create(:user_confirmed, email: "fff@rusty.mails.com") }
        before { stub_const("EmailDomain::EMAIL_MIN_COUNT", 0) }

        it "updates" do
          patch "#{base_url}/#{email_domain.id}", params: {email_domain: {status: "banned"}}

          expect(flash[:success]).to be_present
          expect(email_domain.reload.status).to eq "banned"
        end

        context "with more bikes created" do
          let!(:bike1) { FactoryBot.create(:bike, owner_email: "fff@rusty.mails.com") }
          let!(:bike2) { FactoryBot.create(:bike, owner_email: "ffg@rusty.mails.com") }
          let!(:bike3) { FactoryBot.create(:bike, owner_email: "ffh@rusty.mails.com") }

          it "responds with not likely spam" do
            patch "#{base_url}/#{email_domain.id}", params: {email_domain: {status: "banned"}}
            expect(flash[:error]).to match("bikes")
            expect(email_domain.reload.status).to eq "permitted"
          end
        end
      end
    end
  end
end
