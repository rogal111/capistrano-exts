# Verify that Capistrano is version 2
unless Capistrano::Configuration.respond_to?(:instance)
  abort "This extension requires Capistrano 2"
end

Capistrano::Configuration.instance(:must_exist).load do
  set :monit_templates,fetch(:monit_templates,[])+[File.expand_path(File.join(File.dirname(__FILE__), '..', "templates", "sphinx_monit.erb"))]
  set :configuration_files, fetch(:configuration_files,[])+['config/sphinx.yml']
  
  namespace :sphinx do
    namespace :setup do
      desc "Setup folders and configs"
      task :default, :roles => :app, :except => { :no_release => true } do
        top.sphinx.setup.folders
        top.sphinx.setup.configure
      end
      
      desc "Setup redis folders"
      task :folders, :roles => :app, :except => { :no_release => true } do
        shared_path = fetch :shared_path
        redis = fetch(:redis,{})
        redis.each do |name,v|
          run "#{try_sudo} mkdir -p #{shared_path}/shared_contents/sphinx"
          run "#{try_sudo} mkdir -p #{shared_path}/tmp"
        end
      end
  
      desc "Configure sphinx"
      task :configure, :roles => :app, :except => { :no_release => true } do
        shared_path = fetch :shared_path
        sphinx_template=fetch(:sphinx_template_path,File.expand_path(File.join(File.dirname(__FILE__), '..', "templates", "sphinx.conf")))
        template = File.read(sphinx_template)
        result = ERB.new(template).result(binding)
        put result, "#{shared_path}/config/config_sphinx.yml"
      end
    end
    desc "Generate the Sphinx configuration file"
    task :configure do
      rake "thinking_sphinx:configure"
    end

    desc "Index data"
    task :index do
      rake "thinking_sphinx:index"
    end
    
    desc "Restart Sphinx daemon"
    task :restart do
      sudo "monit restart sphinx_#{fetch(:application)}_#{fetch(:stage)}"
    end

    desc "Stop, re-index and then start the Sphinx daemon"
    task :rebuild do
      sudo "monit stop sphinx_#{fetch(:application)}_#{fetch(:stage)}"
      rake "thinking_sphinx:configure \
        thinking_sphinx:reindex"
      sudo "monit start sphinx_#{fetch(:application)}_#{fetch(:stage)}"
    end
    
    def rake(*tasks)
      rails_env = fetch(:rails_env)
      rake = fetch(:rake, "rake")
      tasks.each do |t|
        run "if [ -d #{release_path} ]; then cd #{release_path}; else cd #{current_path}; fi; if [ -f Rakefile ]; then #{rake} RAILS_ENV=#{rails_env} #{t}; fi;"
      end
    end
  end

after "deploy:setup", "sphinx:setup"
#before "deploy:start", "sphinx:rebuild"
end