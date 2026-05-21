# == Schema Information
#
# Table name: bug_reports
# Database name: primary
#
#  id               :bigint           not null, primary key
#  body             :text
#  from_address     :string
#  from_name        :string
#  received_at      :datetime
#  subject          :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  inbound_email_id :bigint
#
# Indexes
#
#  index_bug_reports_on_inbound_email_id  (inbound_email_id)
#
# Foreign Keys
#
#  fk_rails_...  (inbound_email_id => action_mailbox_inbound_emails.id) ON DELETE => nullify
#
class BugReport < ApplicationRecord
  belongs_to :inbound_email, class_name: "ActionMailbox::InboundEmail", optional: true

  has_many_attached :images

  scope :recent, -> { order(received_at: :desc) }

  def display_subject
    subject.presence || "(no subject)"
  end
end
