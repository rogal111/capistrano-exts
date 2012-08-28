# Verify that Capistrano is version 2
unless Capistrano::Configuration.respond_to?(:instance)
  abort "This extension requires Capistrano 2"
end

RAILS_DB_ADAPTER_MAPPING = {
  'mysql' => 'mysql2'
}

Capistrano::Configuration.instance(:must_exist).load do

  namespace :rails do
    desc "[internal] Create database.yml in shared path"
    task :write_database_yml, :roles => :app, :except => { :no_release => true } do
      database_yml_config_path = "#{fetch :shared_path}/config/config_database.yml"
      unless remote_file_exists?(database_yml_config_path)
        on_rollback { run "rm -f #{database_yml_config_path}" }
        credentials = fetch :mysql_credentials
        db_config_template = fetch :db_config_template
        db_config=if db_config_template and File.exists?(db_config_template)
            config = ERB.new(File.read(db_config_template))
            run "mkdir -p #{shared_path}/config"
            config.result(binding)
        else
          # Get the db_config
          rails_database_yml(credentials, RAILS_DB_ADAPTER_MAPPING)
        end
        # Generate a remote file name
        random_file = random_tmp_file(db_config)
        put db_config, random_file

        begin
          run <<-CMD
            #{try_sudo} cp #{random_file} #{database_yml_config_path}; \
            #{try_sudo} rm -f #{random_file}
          CMD
        rescue Capistrano::CommandError
          logger.info "WARNING: Apparently you do not have permissions to write to #{mysql_credentials_file}."
          find_and_execute_task("mysql:print_#{var}")
        end
      end
    end
  end

  namespace :deploy do
    task :restart, :roles => :app, :except => { :no_release => true } do
      run "#{try_sudo} touch #{File.join(current_path, 'tmp', 'restart.txt')}"
    end
  end

  # Database.yml file
  after "deploy:server:setup:folders", "rails:write_database_yml"
  before "rails:write_database_yml", "mysql:credentials"


  # Capistrano is broken
  # See: https://github.com/capistrano/capistrano/issues/81
  # TODO: Should be conditional, only if bundle:install exists
  #before "deploy:assets:precompile", "bundle:install"
end