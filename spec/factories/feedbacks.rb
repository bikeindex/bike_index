# == Schema Information
#
# Table name: feedbacks
#
#  id                 :integer          not null, primary key
#  body               :text
#  email              :string(255)
#  feedback_hash      :jsonb
#  feedback_type      :string(255)
#  kind               :integer
#  name               :string(255)
#  title              :string(255)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  mailchimp_datum_id :bigint
#  user_id            :integer
#
# Indexes
#
#  index_feedbacks_on_mailchimp_datum_id  (mailchimp_datum_id)
#  index_feedbacks_on_user_id             (user_id)
#
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
