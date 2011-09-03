# encoding: utf-8

# Requirements
require 'capistrano'
require 'capistrano-exts/receipts/deploy'
require 'capistrano-exts/receipts/mysql'
require 'capistrano-exts/receipts/servers/web_server'
require 'capistrano-exts/receipts/servers/db_server'

# Verify that Capistrano is version 2
unless Capistrano::Configuration.respond_to?(:instance)
  abort "This extension requires Capistrano 2"
end

Capistrano::Configuration.instance(:must_exist).load do
  namespace :deploy do
    namespace :server do
      namespace :prepare do
        desc "Prepare the server (database server, web server and folders)"
        task :default do
          # Empty task, server preparation goes into callbacks
        end

        task :folders, :roles => :app do
          run <<-CMD
            mkdir -p #{fetch :deploy_to} &&
            mkdir -p #{fetch :deploy_to}/backups
          CMD

          if exists? :logs_path
            run <<-CMD
              mkdir -p #{fetch :logs_path}
            CMD
          end
        end

        task :finish do
          # Empty task for callbacks
        end

      end
    end
  end

  # Callbacks
  before "deploy:server:prepare", "deploy:server:prepare:folders"
  after  "deploy:server:prepare", "deploy:server:prepare:finish"

  after "deploy:server:prepare:folders", "deploy:server:db_server:prepare"
  after "deploy:server:prepare:folders", "deploy:server:web_server:prepare"
end