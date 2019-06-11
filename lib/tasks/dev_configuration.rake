# frozen_string_literal: true

# Pulling roughly from https://github.com/rails/rails/blob/master/railties/lib/rails/dev_caching.rb
# Inspiration for spring from https://dev.to/evilmartians/living-in-sin-with-spring-48n8

class RakeDevConfiguration
  require "fileutils"
  class << self
    def toggle_dev_caching
      file = "tmp/caching-dev.txt"
      FileUtils.mkdir_p("tmp")

      if File.exist?(file)
        delete_cache_file(file)
        puts "Development mode is no longer being cached."
      else
        create_cache_file(file)
        puts "Development mode is now being cached."
      end

      FileUtils.touch "tmp/restart.txt"
    end

    def toggle_spring
      file = "tmp/spring-off.txt"
      FileUtils.mkdir_p("tmp")

      if File.exist?(file)
        delete_cache_file(file)
        puts "Spring is now enabled."
      else
        create_cache_file(file)
        puts "Spring is no longer enabled (you may need to manually kill the spring processes)"
      end

      FileUtils.touch "tmp/restart.txt" # Probably doesn't do anything right now, but whatever
    end

    def enable_by_argument(caching, file)
      FileUtils.mkdir_p("tmp")

      if caching
        create_cache_file(file)
      elsif caching == false && File.exist?(file)
        delete_cache_file(file)
      end
    end

    private
      def create_cache_file(file)
        FileUtils.touch(file)
      end

      def delete_cache_file(file)
        File.delete(file)
      end
  end
end

namespace :dev do
  task cache: :environment do
    RakeDevConfiguration.toggle_dev_caching
  end

  task spring: :environment do
    RakeDevConfiguration.toggle_spring
  end
end
