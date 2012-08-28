# Verify that Capistrano is version 2
unless Capistrano::Configuration.respond_to?(:instance)
  abort "This extension requires Capistrano 2"
end
Capistrano::Configuration.instance(:must_exist).load do
  namespace :monit do
    desc 'Generate & install monit configuration file for client application'
    task :setup, :roles => [:app] do
      sudo "perl -0777ln -i.bak -e 'BEGIN{$b=\"#----------#{application} #{stage} begin----------\";$e=\"#----------#{application} #{stage} end----------\";}s|\n$b(.*)$e\n||s;print;print \"\n$b\n\include #{shared_path}/config/monit.conf\n$e\n\" if eof;' #{monit_configuration_file} /tmp/tmp_monit_#{application}_#{stage}"
      logger.info "MONIT: Configuration appended to #{monit_configuration_file}."
    end
    
    desc 'Generate & install monit configuration file for client application'
    task :configure, :roles => [:app] do
      monit_template=fetch :monit_template_file
      if File.exists?(monit_template)
        template = File.read(monit_template)
        result = ERB.new(template).result(binding)
        fetch(:monit_templates,[]).each do |template_file|
          result+="\n"+ERB.new(File.read(template_file)).result(binding)
        end
        put result, "#{shared_path}/config/monit.conf"
      else
        put '', "#{shared_path}/config/monit.conf"
      end
    end
    
    desc 'Clear monit configuration'
    task :clear, :roles => [:app] do
      sudo "perl -0777ln -i.bak -e 'BEGIN{$b=\"#----------#{application} #{stage} begin----------\";$e=\"#----------#{application} #{stage} end----------\";}s|\n$b(.*)$e\n||s;print;' #{monit_configuration_file}"
    end
    
    desc 'Reload monit configuration'
    task :reload, :roles => [:app] do
      sudo "/etc/init.d/monit reload"
      logger.info "MONIT: Configuration reloaded."
    end
  end
  
  #after "monit:setup", "monit:reload"
  #after "monit:clear", "monit:reload"
  after "deploy:setup", "monit:configure"
  after "deploy:server:setup:folders", "monit:setup"
  #before "deploy:start", "monit:reload"
end