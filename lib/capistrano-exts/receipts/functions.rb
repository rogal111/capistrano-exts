require 'capistrano'
require 'digest/sha1'
require 'highline'

# Verify that Capistrano is version 2
unless Capistrano::Configuration.respond_to?(:instance)
  abort "This extension requires Capistrano 2"
end

Capistrano::Configuration.instance(:must_exist).load do
  # Taken from Stackoverflow
  # http://stackoverflow.com/questions/1661586/how-can-you-check-to-see-if-a-file-exists-on-the-remote-server-in-capistrano
  def remote_file_exists?(full_path)
    'true' ==  capture("if [ -e #{full_path} ]; then echo 'true'; fi").strip
  end

  def link_file(source_file, destination_file)
    if remote_file_exists?(source_file)
      run "#{try_sudo} ln -nsf #{source_file} #{destination_file}"
    end
  end

  def link_config_file(config_file, config_path = nil)
    config_path ||= "#{File.join release_path, 'config'}"
    link_file("#{File.join shared_path, 'config', config_file}", "#{File.join config_path, config_file}")
  end

  def gen_pass( len = 8 )
      chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
      newpass = ""
      1.upto(len) { |i| newpass << chars[rand(chars.size-1)] }
      return newpass
  end

  def ask(what, options)
    default = options[:default]
    validate = options[:validate] || /(y(es)?)|(no?)|(a(bort)?|\n)/i
    echo = (options[:echo].nil?) ? true : options[:echo]

    ui = HighLine.new
    ui.ask("#{what}?  ") do |q|
      q.overwrite = false
      q.default = default
      q.validate = validate
      q.responses[:not_valid] = what
      unless echo
        q.echo = "*"
      end
    end
  end

  def mysql_db_name(stage = nil)
    stage ||= fetch :stage
    "#{fetch :application}_#{stage}"
  end

  def mysql_db_user
    application = fetch :application
    if application.size > 16
      application.truncate 16, omission: ""
    else
      application
    end
  end

  def mysql_db_hosts
    # TODO: Do some real work here, we shouldn't be allowing all hosts but only all db/web/app hosts.
    ['%']
  end

  def random_tmp_file(data = nil)
    if data.present?
      data_hash = Digest::SHA1.hexdigest data
      "/tmp/#{fetch :application}_#{Time.now.strftime('%d-%m-%Y_%H-%M-%S')}_#{data_hash}"
    else
      "/tmp/#{fetch :application}_#{Time.now.strftime('%d-%m-%Y_%H-%M-%S')}"
    end
  end

  # Helper for some mysql tasks
  def mysql_credentials
    return <<-EOS
      hostname: localhost
      username: #{mysql_db_user}
      password: #{fetch :mysql_db_pass}
    EOS
  end
end