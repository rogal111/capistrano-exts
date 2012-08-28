# Verify that Capistrano is version 2
unless Capistrano::Configuration.respond_to?(:instance)
  abort "This extension requires Capistrano 2"
end

Capistrano::Configuration.instance(:must_exist).load do
  set :monit_templates,fetch(:monit_templates,[])+[File.expand_path(File.join(File.dirname(__FILE__), '..', "templates", "redis_monit.erb"))]
  
  namespace :redis do
    namespace :setup do
      desc "Setup folders and configs"
      task :default, :roles => :app, :except => { :no_release => true } do
        top.redis.setup.folders
        top.redis.setup.configure
      end
      
      desc "Setup redis folders"
      task :folders, :roles => :app, :except => { :no_release => true } do
        shared_path = fetch :shared_path
        redis = fetch(:redis,{})
        redis.each do |name,v|
          run "#{try_sudo} mkdir -p #{shared_path}/shared_contents/redis_#{name}"
        end
      end
  
      desc "Configure redis"
      task :configure, :roles => :app, :except => { :no_release => true } do
        shared_path = fetch :shared_path
        redis = fetch(:redis,{})
        redis.each do |name,v|
          redis_template=fetch(:redis_template_path,File.expand_path(File.join(File.dirname(__FILE__), '..', "templates", "redis.conf")))
          template = File.read(redis_template)
          @redis=v
          @name=name
          @logs_path=fetch(:logs_path,"#{shared_path}/log")
          @shared_path=shared_path
          result = ERB.new(template).result(binding)
          put result, "#{shared_path}/config/redis_<%= name %>.conf"
        end
      end
    end
  end

after "deploy:setup", "redis:setup"
end