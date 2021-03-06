# Verify that Capistrano is version 2
unless Capistrano::Configuration.respond_to?(:instance)
  abort "This extension requires Capistrano 2"
end

require 'fileutils'

Capistrano::Configuration.instance(:must_exist).load do
  namespace :web do

    desc "Symlink system folder"
    task :symlink_system_folder, :roles => :web, :except => { :no_release => true } do
      public_path = fetch(:public_path).gsub(%r{#{current_path}}, latest_release)
      link_file("#{fetch :shared_path}/__system__", "#{public_path}/__system__", false)
    end

    desc <<-DESC
      Present a maintenance page to visitors. Disables your application's web \
      interface by writing a maintenance page to each web server. The \
      servers must be configured to detect the presence of this file, and if \
      it is present, always display it instead of performing the request.

      By default, the maintenance page will just say the site is down for \
      "maintenance", and will be back "shortly", but you can customize the \
      page by specifying the TITLE, REASON and UNTIL environment variables:

        $ cap deploy:web:disable \\
              TITLE="Upgrading" \\
              REASON="hardware upgrade" \\
              UNTIL="12pm Central Time"

      Further customization will require that you write your own task.
    DESC
    task :disable, :roles => :web, :except => { :no_release => true } do
      on_rollback { run "rm -rf #{fetch :shared_path}/__system__/maintenance" }

      # Define the maintenance_url
      maintenance_url = '/__system__/maintenance'

      # Get the maintenance_path or use the default one
      maintenance_path = fetch :maintenance_path,
        File.expand_path(File.join(File.dirname(__FILE__), '..', "templates", "maintenance"))

      # Fetch command line options
      title = ENV['TITLE']
      reason = ENV['REASON']
      deadline = ENV['UNTIL']

      # Create the maintenance folder
      run <<-CMD
        #{try_sudo} mkdir -p #{fetch :shared_path}/__system__/maintenance
      CMD

      if File.directory?(maintenance_path)
        # Generate random names
        random_folder = local_random_tmp_file
        random_file = "#{local_random_tmp_file}.tar.gz"
        # Add a rollback hook
        on_rollback do
          run "rm -f #{random_file}"
          system "rm -rf #{random_file} #{random_folder}"
        end
        # Copy the folder to /tmp
        FileUtils.cp_r maintenance_path, random_folder

        # If we have an rhtml file
        if File.exists?("#{random_folder}/index.rhtml")
          # Read it
          erb_contents = File.read("#{random_folder}/index.rhtml")
          # Delete it
          FileUtils.rm "#{random_folder}/index.rhtml"
          # Write the rendered ERB to the html file
          File.open("#{random_folder}/index.html", 'w') do |f|
            f.write ERB.new(erb_contents).result(binding)
          end
        end

        # Create a local tar file
        system <<-CMD
          cd #{random_folder} &&
          tar chzf #{random_file} --exclude='*~' --exclude='*.tmp' --exclude='*.bak' * &&
          rm -rf #{random_folder}
        CMD

        # Upload the file
        put File.read(random_file), random_file

        # Remove the file locally
        system <<-CMD
          rm -f #{random_file}
        CMD

        # Extract the folder remotely
        run <<-CMD
          cd #{fetch :shared_path}/__system__/maintenance &&
          #{try_sudo} tar xzf #{random_file} &&
          rm -f #{random_file}
        CMD
      else
        erb_contents = File.read(maintenance_path)
        result = ERB.new(erb_contents).result(binding)

        put result, "#{fetch :shared_path}/__system__/maintenance/index.html", :mode => 0644
      end

      if !exists?(:web_server_app) || fetch(:web_server_app) == :apache
        warn <<-EOHTACCESS

          # Please add something like this to your site's htaccess to redirect users to the maintenance page.
          # More Info: http://www.shiftcommathree.com/articles/make-your-rails-maintenance-page-respond-with-a-503

          ErrorDocument 503 /__system__/maintenance/index.html
          RewriteEngine On
          RewriteCond %{REQUEST_URI} !\.(css|js|gif|jpg|png)$
          RewriteCond %{DOCUMENT_ROOT}/__system__/maintenance/index.html -f
          RewriteCond %{SCRIPT_FILENAME} !/__system__/maintenance/index.html
          RewriteRule ^.*$  -  [redirect=503,last]
        EOHTACCESS
      end
    end

    desc <<-DESC
      Makes the application web-accessible again. Removes the \
      "maintenance.html" page generated by deploy:web:disable, which (if your \
      web servers are configured correctly) will make your application \
      web-accessible again.
    DESC
    task :enable, :roles => :web, :except => { :no_release => true } do
      run "rm -rf #{fetch :shared_path}/__system__/maintenance"
    end
  end

  # Dependencies
  after "deploy:finalize_update", "web:symlink_system_folder"
  #after "web:disable", "deploy:fix_permissions"
end
