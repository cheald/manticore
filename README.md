# Manticore

Manticore is a HTTP client with the fast, robust HTTP client built on the Apache HTTPClient libraries. It is only compatible with JRuby.

## Installation

Add this line to your application's Gemfile:

    gem 'manticore'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install manticore

## Usage

Manticore is built around a connection pool. When you create a `Client`, you will pass various parameters that it will use to set up the pool.

    client = Manticore::Client.new(request_timeout: 5, connect_timeout: 5, socket_timeout: 5, pool_max: 10, pool_max_per_route: 2)

Then, you can make requests from the client. Pooling and route maximum constraints are automatically managed:

    response = client.get("http://www.google.com/")

It is recommend that you instantiate a client once, then re-use it, rather than instantiating a new client per request.

Some additional options that may be useful when instantiating the client:

    :user_agent         => string                  - Sets the user agent used in requests.
    :pool_max           => integer (default 64)    - Sets the maximum number of active connections in the pool
    :pool_max_per_route => integer (default 8)     - Sets the maximum number of active connections for a given target endpoint
    :cookies            => boolean (default true)  - enable or disable automatic cookie management between requests
    :compression        => boolean (default true)  - enable or disable transparent gzip/deflate support
    :request_timeout    => integer (default 60)    - Sets the timeout for requests. Raises Manticore::Timeout on failure.
    :connect_timeout    => integer (default 10)    - Sets the timeout for connections. Raises Manticore::Timeout on failure.
    :socket_timeout     => integer (default 10)    - Sets SO_TIMEOUT for open connections. A value of 0 is an infinite timeout. Raises Manticore::Timeout on failure.
    :request_timeout    => integer (default 60)    - Sets the timeout for a given request. Raises Manticore::Timeout on failure.
    :max_redirects      => integer (default 5)     - Sets the maximum number of redirects to follow.
    :expect_continue    => boolean (default false) - Enable support for HTTP 100
    :stale_check        => boolean (default false) - Enable support for stale connection checking. Adds overhead.

Additionally, if you pass a block to the initializer, the underlying [HttpClientBuilder](http://hc.apache.org/httpcomponents-client-ga/httpclient/apidocs/org/apache/http/impl/client/HttpClientBuilder.html) and [RequestConfig.Builder](http://hc.apache.org/httpcomponents-client-ga/httpclient/apidocs/org/apache/http/client/config/RequestConfig.Builder.html) will be yielded so that you can operate on them directly:

    client = Manticore::Client.new(socket_timeout: 5) do |http_client_builder, request_builder|
      http_client_builder.disable_redirect_handling
    end

## To Do

* Concurrent execution wrapper, for executing multiple HTTP requests in parallel from the same control thread.
* Bigger and better spec suite
* One-shot API which routes requests to a default client, so that individual applications don't have to manage a client if they don't want to.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
