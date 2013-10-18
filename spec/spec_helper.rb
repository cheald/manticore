require 'rubygems'
require 'bundler/setup'
require 'manticore'
require 'zlib'
require 'json'

PORT = 55441

def local_server(path = "/")
  URI.join("http://localhost:#{PORT}", path).to_s
end

def start_server
  @server = Thread.new {
    Net::HTTP::Server.run(:port => PORT) do |request, stream|
      if request[:headers]["X-Redirect"] && request[:uri][:path] != request[:headers]["X-Redirect"]
        [301, {"Location" => local_server( request[:headers]["X-Redirect"] )}, [""]]
      else
        if request[:headers]["Accept-Encoding"] && request[:headers]["Accept-Encoding"].match("gzip")
          out = StringIO.new('', "w")
          io = Zlib::GzipWriter.new(out, 2)
          io.write JSON.dump(request)
          io.close
          payload = out.string
          [200, {'Content-Type' => "text/plain", 'Content-Encoding' => "gzip", "Content-Length" => payload.length}, [payload]]
        else
          payload = JSON.dump(request)
          [200, {'Content-Type' => "text/plain", "Content-Length" => payload.length}, [payload]]
        end
      end
    end
  }
end

def stop_server
  @server.kill if @server
end

RSpec.configure do |c|
  require 'net/http/server'

  c.before(:suite) { start_server }
  c.after(:suite)  { stop_server  }
end