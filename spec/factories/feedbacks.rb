FactoryBot.define do
  factory :feedback do
    email { "foo@boy.com" }
    body { "This is a test email." }
    title { "New Feedback Submitted" }
    name { "Bobby Joe" }
    factory :feedback_serial_update_request do
      transient do
        bike { FactoryBot.create(:bike) }
      end
      feedback_type { "serial_update_request" }
      feedback_hash { {bike_id: bike.id} }
    end
    factory :feedback_bike_delete_request do
      transient do
        bike { FactoryBot.create(:bike) }
      end
      feedback_type { "bike_delete_request" }
      feedback_hash { {bike_id: bike.id} }
    end
  end
end
