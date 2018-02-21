require 'spec_helper'

# This entire thing is commented out because it requires putting in the API key and the list ID for mailchimp - which we don't want to expose
# So rather than doing that, just run this if it needs to run and manually put in the ENV variables

# describe UpdateMailchimpUserWorker do
#   it { is_expected.to be_processed_in :notify }
#   let(:subject) { UpdateMailchimpUserWorker }
#   let(:instance) { subject.new }

#   def mailchimp_user_exists?(user)
#     instance.mailchimp_user(user).retrieve
#     true # The user exists!
#   rescue Gibbon::MailChimpError => e
#     # User does not exist if the unable to find the resource
#     return false if e.title == 'Resource Not Found'
#     raise e
#   end

#   describe 'perform' do
#     let(:created_at) { Time.now - 3.days }
#     let!(:user) { FactoryGirl.create(:confirmed_user, email: email, name: 'parrtyyyy XOXO', is_emailable: true, created_at: created_at) }

#     context 'user on mailchimp' do
#       context 'user marked unsubscribed' do
#         let(:email) { 'testly1+unsubscribed@spin.pm' }
#         let(:mailchimp_user_attrs) do
#           {
#             body: {
#               email_address: user.email,
#               status: 'unsubscribed',
#               merge_fields: { SIGNED_UP: created_at.strftime('%m/%d/%Y') }
#             }
#           }
#         end
#         it 'does not change the users subscription status' do
#           # Ensure the user exists on Mailchimp and is unsubscribed
#           if mailchimp_user_exists?(user)
#             mailchimp_user = instance.mailchimp_user(user).retrieve.body
#             expect(mailchimp_user[:status]).to eq 'unsubscribed'
#           else
#             instance.mailchimp_user(user).upsert(mailchimp_user_attrs)
#           end
#           instance.perform(user.id)

#           mailchimp_user = instance.mailchimp_user(user).retrieve.body
#           expect(mailchimp_user[:status]).to eq 'unsubscribed'
#         end
#       end
#     end
#     context 'user not on mailchimp' do
#       let(:email) { 'testly+not_present@bikeindex.org' }
#       context 'valid email' do
#         it 'creates the user' do
#           FactoryGirl.create(:ownership, user: user)
#           expect(user.confirmed?).to be_truthy
#           expect(user.add_to_mailchimp?).to be_truthy
#           if mailchimp_user_exists?(user)
#             instance.mailchimp_user(user).delete
#           end
#           instance.perform(user.id)
#           mailchimp_user = instance.mailchimp_user(user).retrieve.body

#           expect(mailchimp_user[:merge_fields][:NAME]).to eq 'parrtyyyy XOXO'
#           expect(mailchimp_user[:merge_fields][:SIGNED_UP]).to eq created_at.strftime('%Y-%m-%d')
#           expect(mailchimp_user[:merge_fields][:BIKE_COUNT]).to eq 1
#         end
#       end
#     end
#   end

#   describe 'create the merge fields' do
#     xit 'creates the fields' do
#       mailchimp_response = instance.mailchimp_request.lists(subject::LIST_ID).merge_fields.retrieve
#       count = mailchimp_response.body[:total_items]
#       expect(count).to eq 3 # This will need to be changed when things are added, but it's useful for testing rn
#       names = mailchimp_response.body[:merge_fields].map { |i| i[:name] }
#       expect(names.map(&:downcase).uniq.count).to eq count

#       mailchimp_response.body[:merge_fields].each do |merge_field|
#         job_field = subject.required_merge_fields.select do |f|
#           f[:name] == merge_field[:name]
#         end.first
#         expect(merge_field[:tag]).to eq job_field[:tag]
#       end

#       # Here for posterity: delete merge fields en-mass, create them from the job
#       # Should remain commented out unless you're doing something special
#       # Array(1..6).each do |id|
#       #   pp instance.mailchimp_request.lists(subject::LIST_ID).merge_fields(id).delete
#       # end
#       # UpdateMailchimpUserWorker.add_merge_fields
#     end
#   end
# end
