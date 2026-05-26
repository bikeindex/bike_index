# frozen_string_literal: true

# Pulling roughly from https://github.com/rails/rails/blob/master/railties/lib/rails/dev_caching.rb

class RakeDevConfiguration
  require "fileutils"
  class << self
    def toggle_letter_opener
      file = "tmp/enable-letter_opener.txt"
      FileUtils.mkdir_p("tmp")

      if File.exist?(file)
        delete_toggle_file(file)
        puts "letter_opener is now disabled."
      else
        create_toggle_file(file)
        puts "letter_opener is now enabled."
      end

      FileUtils.touch "tmp/restart.txt"
    end

    def toggle_lograge
      file = "tmp/non-lograge-dev.txt"
      FileUtils.mkdir_p("tmp")

      if File.exist?(file)
        delete_toggle_file(file)
        puts "Logging using lograge"
      else
        create_toggle_file(file)
        puts "Logging using Rails logger (not lograge)"
      end

      FileUtils.touch "tmp/restart.txt"
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
  # desc "Toggle caching" - already a rake action, no need to add our own

  desc "Toggle letter_opener gem, which automatically opens sent emails in a browser window"
  task letter_opener: :environment do
    RakeDevConfiguration.toggle_letter_opener
  end

  desc "Toggle lograge logging in development"
  task lograge: :environment do
    RakeDevConfiguration.toggle_lograge
  end
end
