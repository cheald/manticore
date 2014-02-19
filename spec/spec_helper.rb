require 'rubygems'
require 'bundler/setup'
require 'manticore'
require 'zlib'
require 'json'
require 'rack'

PORT = 55441

def local_server(path = "/", port = PORT)
  URI.join("http://localhost:#{port}", path).to_s
end

def read_nonblock(socket)
  buffer = ""
  loop {
     begin
         buffer << socket.read_nonblock(4096)
     rescue Errno::EAGAIN
         # Resource temporarily unavailable - read would block
         break
     end
  }
  buffer
end

def start_server(port = PORT)
  @servers ||= {}
  @servers[port] = Thread.new {
    Net::HTTP::Server.run(port: port) do |request, stream|

      query = Rack::Utils.parse_query(request[:uri][:query].to_s)
      if query["sleep"]
        sleep(query["sleep"].to_f)
      end

      if cl = request[:headers]["Content-Length"]
        request[:body] = read_nonblock stream.socket
      end

      content_type = request[:headers]["X-Content-Type"] || "text/plain"
      if request[:uri][:path] == "/auth"
        if request[:headers]["Authorization"] == "Basic dXNlcjpwYXNz"
          payload = JSON.dump(request)
          [200, {'Content-Type' => content_type, "Content-Length" => payload.length}, [payload]]
        else
          [401, {'WWW-Authenticate' => 'Basic realm="test"'}, [""]]
        end
      elsif request[:uri][:path] == "/proxy"
        payload = JSON.dump(request.merge(server_port: port))
        [200, {'Content-Type' => content_type, "Content-Length" => payload.length}, [payload]]
      elsif request[:headers]["X-Redirect"] && request[:uri][:path] != request[:headers]["X-Redirect"]
        [301, {"Location" => local_server( request[:headers]["X-Redirect"] )}, [""]]
      else
        if request[:headers]["Accept-Encoding"] && request[:headers]["Accept-Encoding"].match("gzip")
          out = StringIO.new('', "w")
          io = Zlib::GzipWriter.new(out, 2)
          io.write JSON.dump(request)
          io.close
          payload = out.string
          [200, {'Content-Type' => content_type, 'Content-Encoding' => "gzip", "Content-Length" => payload.length}, [payload]]
        else
          payload = JSON.dump(request)
          [200, {'Content-Type' => content_type, "Content-Length" => payload.length}, [payload]]
        end
      end
    end
  }
end

def stop_servers
  @servers.values.each(&:kill) if @servers
end

RSpec.configure do |c|
  require 'net/http/server'

  c.before(:suite) {
    @server = {}
    start_server 55441
    start_server 55442
  }

  c.after(:suite)  { stop_servers }
end