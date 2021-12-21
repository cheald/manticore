# this is a generated file, to avoid over-writing it just delete this comment
begin
  require 'jar_dependencies'
rescue LoadError
  require 'commons-logging/commons-logging/1.2/commons-logging-1.2.jar'
  require 'commons-codec/commons-codec/1.15/commons-codec-1.15.jar'
  require 'org/apache/httpcomponents/httpcore/4.4.14/httpcore-4.4.14.jar'
  require 'org/apache/httpcomponents/httpclient/4.5.13/httpclient-4.5.13.jar'
  require 'org/apache/httpcomponents/httpmime/4.5.13/httpmime-4.5.13.jar'
end

if defined? Jars
  require_jar 'commons-logging', 'commons-logging', '1.2'
  require_jar 'commons-codec', 'commons-codec', '1.15'
  require_jar 'org.apache.httpcomponents', 'httpcore', '4.4.14'
  require_jar 'org.apache.httpcomponents', 'httpclient', '4.5.13'
  require_jar 'org.apache.httpcomponents', 'httpmime', '4.5.13'
end
