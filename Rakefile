require "bundler/gem_tasks"

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rspec_opts = ['--tty --color --format documentation']
end
task :default => [:generate_certs, :spec]

require 'rake/javaextensiontask'

# Dependency jars for the Kerrigan ext build
jars = [
  "#{ENV['MY_RUBY_HOME']}/lib/jruby.jar",
  "lib/jar/httpcore-4.3.3.jar",
  "lib/jar/httpclient-4.3.6.jar"
]
Rake::JavaExtensionTask.new do |ext|
  ext.name = "manticore-ext"
  ext.lib_dir = "lib/jar"
  ext.classpath = jars.map {|x| File.expand_path x}.join ':'
end

task :generate_certs do
  root = File.expand_path("../spec/ssl", __FILE__)
  openssl = `which openssl`.strip
  keytool = `which keytool`.strip

  Dir.glob("#{root}/*").each {|f| File.unlink f }

  # Create the CA
  cmds = [
    "#{openssl} genrsa | #{openssl} pkcs8 -topk8 -nocrypt -out #{root}/root-ca.key",
    "#{openssl} req -sha256 -x509 -new -nodes -key #{root}/root-ca.key -days 365 -out #{root}/root-ca.crt -subj \"/C=US/ST=The Internet/L=The Internet/O=Manticore CA/OU=Manticore/CN=localhost\"",

    # Create the client CSR, key, and signed cert
    "#{openssl} genrsa | #{openssl} pkcs8 -topk8 -nocrypt -out #{root}/client.key",
    "#{openssl} req -sha256 -key #{root}/client.key -new -out #{root}/client.csr -subj \"/C=US/ST=The Internet/L=The Internet/O=Manticore Client/OU=Manticore/CN=localhost\"",
    "#{openssl} x509 -req -in #{root}/client.csr -CA #{root}/root-ca.crt -CAkey #{root}/root-ca.key -CAcreateserial -out #{root}/client.crt -days 1",
    #{ }"cat #{root}/client.crt #{root}/client.key > #{root}/client.pem",

    # Create the server cert
    "#{openssl} genrsa | #{openssl} pkcs8 -topk8 -nocrypt -out #{root}/host.key",
    "#{openssl} req -sha256 -key #{root}/host.key -new -out #{root}/host.csr -subj \"/C=US/ST=The Internet/L=The Internet/O=Manticore Host/OU=Manticore/CN=localhost\"",
    "#{openssl} x509 -req -in #{root}/host.csr -CA #{root}/root-ca.crt -CAkey #{root}/root-ca.key -CAcreateserial -out #{root}/host.crt -days 1",
    # "#{openssl} ca -out #{root}/host.crt -infiles #{root}/host.csr",
    #{ }"cat #{root}/host.crt #{root}/host.key > #{root}/host.pem",

    "#{keytool} -import -file #{root}/root-ca.crt -alias rootCA -keystore #{root}/truststore.jks -noprompt -storepass test123",
    "#{openssl} pkcs12 -export -clcerts -out #{root}/client.p12 -inkey #{root}/client.key -in #{root}/client.crt -certfile #{root}/root-ca.crt -password pass:test123",
  ]

  cmds.each.with_index {|cmd, index| puts "#{index}. #{cmd}"; system cmd }
end