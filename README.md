# Manticore

[![Build Status](https://travis-ci.org/cheald/manticore.png?branch=master)](https://travis-ci.org/cheald/manticore)

Manticore is a fast, robust HTTP client built on the Apache HTTPClient libraries. It is only compatible with JRuby.

## Installation

Add this line to your application's Gemfile:

    gem 'manticore'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install manticore

## Documentation

  Documentation is available [at rubydoc.info](http://rubydoc.info/github/cheald/manticore/master/frames).

## Performance

  Manticore is [very fast](https://github.com/cheald/manticore/wiki/Performance).

## Major Features

  As it's built on the Apache Commons HTTP components, Manticore is very rich. It includes support for:

  * Keepalive connections (and connection pooling)
  * Transparent gzip and deflate handling
  * Transparent cookie handling
  * Both synchronous and asynchronous execution models
  * SSL
  * Much more!

## Usage

### Quick Start

If you don't want to worry about setting up and maintaining client pools, Manticore comes with a facade that you can use to start making requests right away:

    Manticore.get "http://www.google.com/"

Additionally, you can mix the `Manticore::Facade` into your own class for similar behavior:

    class MyClient
      include Manticore::Facade
      include_http_client user_agent: "MyClient/1.0"
    end

    MyClient.get "http://www.google.com/"

Mixing the client into a class will create a new new pool. If you want to share a single pool between clients, specify the `shared_pool` option:

    class MyClient
      include Manticore::Facade
      include_http_client shared_pool: true
    end

    class MyOtherClient
      include Manticore::Facade
      include_http_client shared_pool: true
    end

### More Control

Manticore is built around a connection pool. When you create a `Client`, you will pass various parameters that it will use to set up the pool.

    client = Manticore::Client.new(request_timeout: 5, connect_timeout: 5, socket_timeout: 5, pool_max: 10, pool_max_per_route: 2)

Then, you can make requests from the client. Pooling and route maximum constraints are automatically managed:

    response = client.get("http://www.google.com/")

It is recommend that you instantiate a client once, then re-use it, rather than instantiating a new client per request.

Additionally, if you pass a block to the initializer, the underlying [HttpClientBuilder](http://hc.apache.org/httpcomponents-client-ga/httpclient/apidocs/org/apache/http/impl/client/HttpClientBuilder.html) and [RequestConfig.Builder](http://hc.apache.org/httpcomponents-client-ga/httpclient/apidocs/org/apache/http/client/config/RequestConfig.Builder.html) will be yielded so that you can operate on them directly:

    client = Manticore::Client.new(socket_timeout: 5) do |http_client_builder, request_builder|
      http_client_builder.disable_redirect_handling
    end

### Parallel execution

Manticore can perform multiple concurrent execution of requests.

    client = Manticore::Client.new

    # These aren't actually executed until #execute! is called.
    # You can define response handlers in a block when you queue the request:
    client.async_get("http://www.google.com") {|req|
      req.on_success do |response|
        puts response.body
      end

      req.on_failure do |exception|
        puts "Boom! #{exception.message}"
      end
    }

    # ...or by invoking the method on the queued response returned:
    response = client.async_get("http://www.yahoo.com")
    response.on_success do |response|
      puts "The length of the Yahoo! homepage is #{response.body.length}"
    end

    # ...or even by chaining them onto the call
    client.async_get("http://bing.com").
      on_success {|r| puts r.code }.
      on_failure {|e| puts "on noes!"}

    client.execute!

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
