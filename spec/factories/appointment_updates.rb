FactoryBot.define do
  factory :appointment_update do
    appointment { FactoryBot.create(:appointment) }
    status { Appointment.statuses.first }
  end
end
