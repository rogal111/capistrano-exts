require 'capistrano'
require 'capistrano/errors'
require 'capistrano-exts/receipts/functions'

# Verify that Capistrano is version 2
unless Capistrano::Configuration.respond_to?(:instance)
  abort "This extension requires Capistrano 2"
end

Capistrano::Configuration.instance(:must_exist).load do
  namespace :contents do
    desc "Setup the contents folder"
    task :setup, :roles => :app, :except => { :no_release => true } do
      shared_path = fetch :shared_path
      contents_folder = fetch :contents_folder

      run <<-CMD
        #{try_sudo} mkdir -p #{shared_path}/shared_contents
      CMD

      contents_folder.each do |folder, path|
        run <<-CMD
          #{try_sudo} mkdir -p #{shared_path}/shared_contents/#{folder}
        CMD
      end
    end

    desc "[internal] Fix contao's symlinks to the shared path"
    task :fix_links, :roles => :app, :except => { :no_release => true } do
      contents_folder = fetch :contents_folder
      current_path = fetch :current_path
      latest_release = fetch :latest_release
      shared_path = fetch :shared_path

      contents_folder.each do |folder, path|
        # At this point, the current_path does not exists and by running an mkdir
        # later, we're actually breaking stuff.
        # So replace current_path with latest_release in the contents_path string
        path.gsub! %r{#{current_path}}, latest_release

        # Remove the path, making sure it does not exists
        run <<-CMD
          #{try_sudo} rm -f #{path}
        CMD

        # Make sure we have the folder that'll contain the shared path
        run <<-CMD
          #{try_sudo} mkdir -p #{File.dirname(path)}
        CMD

        # Create the symlink
        run <<-CMD
          #{try_sudo} ln -nsf #{shared_path}/shared_contents/#{folder} #{path}
        CMD
      end
    end

    desc "Export the contents folder"
    task :export, :roles => :app, :except => { :no_release => true } do
      shared_path = fetch :shared_path

      # Create random file name
      random_file = random_tmp_file + ".tar.gz"

      # Create a tarball of the contents folder
      run <<-CMD
        cd #{shared_path} &&
        tar czf #{random_file} --exclude='*~' --exclude='*.tmp' --exclude='*.bak' shared_contents
      CMD

      # Tranfer the contents to the local system
      get random_file, random_file

      puts "Contents has been downloaded to #{random_file}"
    end
  end

  after "deploy:setup", "contents:setup"
  after "deploy:finalize_update", "contents:fix_links"
end