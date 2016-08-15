class StolenRecordRecoverer
  def update(stolen_record_id, info)
    stolen_record = StolenRecord.unscoped.find(stolen_record_id)
    stolen_record.add_recovery_information(ActiveSupport::HashWithIndifferentAccess.new(info))
    stolen_record.save
  end
end
