require "rails_helper"

RSpec.describe AppointmentMailer, type: :mailer do
  let(:location) { FactoryBot.create(:location, :with_virtual_line_on) }
  let(:organization) { location.organization }
  let(:organization_member) { FactoryBot.create(:organization_member, organization: organization) }
  before { organization.update(auto_user: organization_member) }
  let(:header_mail_snippet) do
    FactoryBot.create(:organization_mail_snippet,
                      kind: "header",
                      organization: organization,
                      body: "<p>HEADERXSNIPPET</p>")
  end

  let(:user) { FactoryBot.create(:user_confirmed) }
  let(:appointment) { FactoryBot.create(:appointment, organization: organization, location: location, user: user) }

  describe "view_appointment" do
    it "renders, with reply to for the organization" do
      expect(header_mail_snippet).to be_present
      organization.reload
      expect(organization.auto_user).to eq organization_member
      mail = AppointmentMailer.view_appointment(appointment)
      expect(mail.subject).to eq("View your place in the #{organization.short_name} line")
      expect(appointment.email).to eq user.email
      expect(mail.to).to eq([user.email])
      expect(mail.reply_to).to eq([organization.auto_user.email])
      expect(mail.body.encoded).to match header_mail_snippet.body
      expect(mail.body.encoded).to match(appointment.link_token)
    end
  end
end
