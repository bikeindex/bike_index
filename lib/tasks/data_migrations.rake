namespace :data do
  namespace :migrate_info_hash do
    desc "Migrate customer_contacts.info_hash_text to info_hash"
    task up: :environment do
      customer_contacts = CustomerContact.where.not(info_hash: nil)
      total_count = customer_contacts.count
      digits = total_count.to_s.length

      puts "Updating #{total_count} customer_contact records..."

      ActiveRecord::Base.transaction do
        customer_contacts.find_each.with_index(1) do |customer_contact, i|
          customer_contact.update(info_hash: customer_contact.info_hash_text)

          $stdout.print "#{i.to_s.rjust(digits, " ")}/#{total_count}\r"
          $stdout.flush
        end
      end

      puts "Done!"
    end

    desc "Migrate customer_contacts.info_hash to info_hash_text"
    task down: :environment do
      customer_contacts = CustomerContact.where.not(info_hash: {})
      total_count = customer_contacts.count
      digits = total_count.to_s.length

      puts "Updating #{total_count} customer_contact records..."

      ActiveRecord::Base.transaction do
        customer_contacts.find_each.with_index(1) do |customer_contact, i|
          customer_contact.update(info_hash_text: customer_contact.info_hash)

          $stdout.print "#{i.to_s.rjust(digits, " ")}/#{total_count}\r"
          $stdout.flush
        end
      end

      puts "Done!"
    end
  end
end
