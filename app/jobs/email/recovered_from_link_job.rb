# frozen_string_literal: true

class Email::RecoveredFromLinkJob < ApplicationJob
  sidekiq_options queue: "notify", retry: 3

  def perform(stolen_record_id)
    stolen_record = StolenRecord.current_and_not.find(stolen_record_id)
    CustomerMailer.recovered_from_link(stolen_record).deliver_now
  end
end
