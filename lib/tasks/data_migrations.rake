namespace :data do
  desc "Migrate customer_contacts.info_hash to info_hash_json"
  task migrate_info_hash: :environment do
    customer_contacts = CustomerContact.where.not(info_hash: nil)
    total_count = customer_contacts.count
    digits = total_count.to_s.length

    puts "Updating #{total_count} customer_contact records..."

    ActiveRecord::Base.transaction do
      customer_contacts.find_each.with_index(1) do |customer_contact, i|
        customer_contact.update(info_hash_json: customer_contact.info_hash)

        $stdout.print "#{i.to_s.rjust(digits, " ")}/#{total_count}\r"
        $stdout.flush
      end
    end

    puts "Done!"
  end
end
