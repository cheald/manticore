require "bundler/gem_tasks"
require "base64"

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = "spec/**/*_spec.rb"
  spec.rspec_opts = ["--tty --color --format documentation"]
end
task :default => [:generate_certs, :spec]

# Download and vendor the jars needed
require "jars/installer"
task :install_jars do
  Jars::Installer.vendor_jars!
end

## Build the Manticore extensions into a jar. You may need to install_jars first
# Dependency jars for the Manticore ext build
require "rake/javaextensiontask"
jars = ["#{ENV["MY_RUBY_HOME"]}/lib/jruby.jar"] + Dir.glob("lib/**/*.jar")
jars.reject! { |j| j.match("manticore-ext") }
Rake::JavaExtensionTask.new do |ext|
  ext.name = "manticore-ext"
  ext.lib_dir = "lib/org/manticore"
  ext.classpath = jars.map { |x| File.expand_path x }.join ":"
end

# Generate all the stuff we need for a full test run
task :generate_certs do
  root = File.expand_path("../spec/ssl", __FILE__)
  openssl = `which openssl`.strip
  keytool = `which keytool`.strip

  Dir.glob("#{root}/*").each { |f| File.unlink f }

  print 'Generating a key that ends with a whitespace character'
  whitespace_found = false
  until whitespace_found
    putc '.'
    key_str = ''
    IO.popen("#{openssl} genrsa 4096 2>/dev/null") { |openssl_io| key_str = openssl_io.read }
    key_parts = key_str.scan(/(?:^-----BEGIN(.* )PRIVATE KEY-----\n)(.*?)(?:-----END\1PRIVATE KEY.*$)/m)
    key_parts.each do |_type, b64key|
      body = Base64.decode64 b64key
      body != body.strip && whitespace_found = true
    end
  end
  puts ' Found'
  IO.popen("#{openssl} pkcs8 -topk8 -nocrypt -out #{root}/client_whitespace.key", 'r+') do |openssl_io|
    openssl_io.puts key_str
    openssl_io.close_write
  end

  cmds = [
    # Create the CA
    "#{openssl} genrsa 4096 | #{openssl} pkcs8 -topk8 -nocrypt -out #{root}/root-ca.key",
    "#{openssl} req -sha256 -x509 -newkey rsa:4096 -nodes -key #{root}/root-ca.key -sha256 -days 365 -out #{root}/root-ca.crt -subj \"/C=US/ST=The Internet/L=The Internet/O=Manticore CA/OU=Manticore/CN=localhost\"",
    "#{openssl} req -sha256 -x509 -newkey rsa:4096 -nodes -key #{root}/root-ca.key -sha256 -days 365 -out #{root}/root-untrusted-ca.crt -subj \"/C=US/ST=The Darknet/L=The Darknet/O=Manticore CA/OU=Manticore/CN=localhost\"",

    # Create the client CSR, key, and signed cert
    "#{openssl} genrsa 4096 | #{openssl} pkcs8 -topk8 -nocrypt -out #{root}/client.key",
    "#{openssl} req -sha256 -key #{root}/client.key -newkey rsa:4096 -out #{root}/client.csr -subj \"/C=US/ST=The Internet/L=The Internet/O=Manticore Client/OU=Manticore/CN=localhost\"",
    "#{openssl} x509 -req -in #{root}/client.csr -CA #{root}/root-ca.crt -CAkey #{root}/root-ca.key -CAcreateserial -out #{root}/client.crt -sha256 -days 1",
    "#{openssl} x509 -req -in #{root}/client.csr -CA #{root}/root-ca.crt -CAkey #{root}/root-ca.key -CAcreateserial -out #{root}/client-expired.crt -sha256 -days -7",

    # Create the client_whitespace CSR and signed cert
    "#{openssl} req -sha256 -key #{root}/client_whitespace.key -newkey rsa:4096 -out #{root}/client_whitespace.csr -subj \"/C=US/ST=The Internet/L=The Internet/O=Manticore Client/OU=Manticore/CN=localhost\"",
    "#{openssl} x509 -req -in #{root}/client_whitespace.csr -CA #{root}/root-ca.crt -CAkey #{root}/root-ca.key -CAcreateserial -out #{root}/client_whitespace.crt -sha256 -days 1",

    # Create the server cert
    "#{openssl} genrsa 4096 | #{openssl} pkcs8 -topk8 -nocrypt -out #{root}/host.key",
    "#{openssl} req -sha256 -key #{root}/host.key -newkey rsa:4096 -out #{root}/host.csr -subj \"/C=US/ST=The Internet/L=The Internet/O=Manticore Host/OU=Manticore/CN=localhost\"",
    "#{openssl} x509 -req -in #{root}/host.csr -CA #{root}/root-ca.crt -CAkey #{root}/root-ca.key -CAcreateserial -out #{root}/host.crt -sha256 -days 1",
    "#{openssl} x509 -req -in #{root}/host.csr -CA #{root}/root-ca.crt -CAkey #{root}/root-ca.key -CAcreateserial -out #{root}/host-expired.crt -sha256 -days -7",
    "#{openssl} x509 -req -in #{root}/host.csr -CA #{root}/root-untrusted-ca.crt -CAkey #{root}/root-ca.key -CAcreateserial -out #{root}/host-untrusted.crt -sha256 -days 1",

    "#{keytool} -import -file #{root}/root-ca.crt -alias rootCA -keystore #{root}/truststore.jks -noprompt -storepass test123",
    "#{openssl} pkcs12 -export -clcerts -out #{root}/client.p12 -inkey #{root}/client.key -in #{root}/client.crt -certfile #{root}/root-ca.crt -password pass:test123",
  ]

  cmds.each.with_index { |cmd, index| puts "#{index}. #{cmd}"; system cmd }
end
