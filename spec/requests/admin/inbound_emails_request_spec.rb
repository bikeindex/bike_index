# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::InboundEmailsController, type: :request do
  include_context :request_spec_logged_in_as_superuser

  base_url = "/admin/inbound_emails"

  describe "#index" do
    let!(:inbound_email) { ActionMailbox::InboundEmail.create_and_extract_message_id!(source_fixture("marketplace_reply")) }

    it "responds with ok" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(flash).to_not be_present
      expect(assigns(:collection).pluck(:id)).to eq([inbound_email.id])
    end
  end

  describe "#show" do
    let!(:inbound_email) { ActionMailbox::InboundEmail.create_and_extract_message_id!(source_fixture("marketplace_reply")) }

    it "responds with ok" do
      get "#{base_url}/#{inbound_email.id}"
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
      expect(flash).to_not be_present
    end
  end

  private

  def source_fixture(name)
    File.read(Rails.root.join("spec/fixtures/files/email/#{name}.eml"))
  end
end
