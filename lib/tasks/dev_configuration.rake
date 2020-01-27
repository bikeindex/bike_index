# frozen_string_literal: true

# Pulling roughly from https://github.com/rails/rails/blob/master/railties/lib/rails/dev_caching.rb

class RakeDevConfiguration
  require "fileutils"
  class << self
    def toggle_dev_caching
      file = "tmp/caching-dev.txt"
      FileUtils.mkdir_p("tmp")

      if File.exist?(file)
        delete_toggle_file(file)
        puts "Development mode is no longer being cached."
      else
        create_toggle_file(file)
        puts "Development mode is now being cached."
      end

      FileUtils.touch "tmp/restart.txt"
    end

    def toggle_letter_opener
      file = "tmp/skip-letter_opener.txt"
      FileUtils.mkdir_p("tmp")

      if File.exist?(file)
        delete_toggle_file(file)
        puts "letter_opener is now enabled"
      else
        create_toggle_file(file)
        puts "letter_opener is disabled."
      end

      FileUtils.touch "tmp/restart.txt" # Probably doesn't do anything right now, but whatever
    end

    private

    def create_toggle_file(file)
      FileUtils.touch(file)
    end

    def delete_toggle_file(file)
      File.delete(file)
    end
  end
end

namespace :dev do
  desc "Toggle caching"
  task cache: :environment do
    RakeDevConfiguration.toggle_dev_caching
  end

  desc "Toggle letter_opener gem, which automatically opens sent emails in a browser window"
  task letter_opener: :environment do
    RakeDevConfiguration.toggle_letter_opener
  end
end
