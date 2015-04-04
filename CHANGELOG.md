## v0.4

### v0.4.1 (pending)

* Add support for ssl[:ca_file], ssl[:client_cert], and ssl[:client_key], to emulate OpenSSL features in other Ruby HTTP clients
* Integrate Faraday adapter for Manticore

### v0.4.0

* Proxy authentication is now supported
* Client#execute! no longer propagates exceptions; these should be handled in `on_failure`.
* Client#http and AsyncProxy now properly accept #delete
* Response#on_complete now receives the request as an argument

## v0.3

### v0.3.6

* GET requests may now accept bodies much like POST requests. Fixes interactions with Elasticsearch.

### v0.3.5

* Stubs now accept regexes for URLs in addition to strings (thanks @gmassanek)

### v0.3.4

* Fixed an issue that caused the presence of request-specific options (ie, max_redirects) to cause the request to use a
  default settings config, rather than respecting the client options. (thanks @zanker)
* Turn off connection state tracking by default; this enables connections to be shared across threads, and shouldn't be an
  issue for most installs. If you need it on, pass :ssl => {:track_state => true} when instantiating a client. (thanks @zanker)

### v0.3.3

* Update to HttpCommons 4.3.6
* Added Response#message (thanks @zanker)
* Fix issues with HTTP error messages that didn't contain a useful message
* Fixed an issue that would prevent the :protocols and :cipher_suites options from working

### v0.3.2
* :ignore_ssl_validation is now deprecated. It has been replaced with :ssl, which takes a hash of options. These include:

        :verify               - :strict (default), :browser, :none -- Specify hostname verification behaviors.
        :protocols            - An array of protocols to accept
        :cipher_suites        - An array of cipher suites to accept
        :truststore           - Path to a keytool trust store, for specifying custom trusted certificate signers
        :truststore_password  - Password for the file specified in `:truststore`
        :truststore_type      - Specify the trust store type (JKS, PKCS12)
        :keystore             - Path to a keytool trust store, for specifying client authentication certificates
        :keystore_password    - Password for the file specified in `:keystore`
        :keystore_type        - Specify the key store type (JKS, PKCS12)

  (thanks @torrancew)

* Fix encodings for bodies (thanks @synhaptein)

### v0.3.1
* Added `automatic_retries` (default 3) parameter to client. The client will automatically retry requests that failed
  due to socket exceptions and empty responses up to this number of times. The most practical effect of this setting is
  to automatically retry when the pool reuses a connection that a client unexpectedly closed.
* Added `request_timeout` to the RequestConfig used to construct requests.
* Fixed implementation of the `:query` parameter for GET, HEAD, and DELETE requests.

### v0.3.0

* Major refactor of `Response`/`AsyncResponse` to eliminate redundant code. `AsyncResponse` has been removed and
  its functionality has been rolled into `Response`.
* Added `StubbedResponse`, a subclass of `Response`, to be used for stubbing requests/responses for testing.
* Added `Client#stub`, `Client#unstub` and `Client#respond_with`
* Responses are now lazy-evaluated by default (similar to how `AsyncResponse` used to behave). The following
  rules apply:
  * Synchronous responses which do NOT pass a block are lazy-evaluated the first time one of their results is requested.
  * Synchronous responses which DO pass a block are evaluated immediately, and are passed to the handler block.
  * Async responses are always evaluted when `Client#execute!` is called.
* You can evaluate a `Response` at any time by invoking `#call` on it. Invoking an async response before `Client#execute`
  is called on it will cause `Client#execute` to throw an exception.
* Responses (both synchronous and async) may use on_success handlers and the like.

## v0.2
### v0.2.1

* Added basic auth support
* Added proxy support
* Added support for per-request cookies (as opposed to per-session cookies)
* Added a `Response#cookies` convenience method.

### v0.2.0

* Added documentation and licenses
* Significant performance overhaul
* Response handler blocks are now only yielded the Response. `#request` is available on
  the response object.
* Patched httpclient.jar to address https://issues.apache.org/jira/browse/HTTPCLIENT-1461
