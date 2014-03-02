## v0.3
### v0.3.0 (pending)

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