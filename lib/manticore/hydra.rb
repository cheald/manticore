module Manticore
  class Hydra
    def initialize(max_connections, max_per_route)
      PoolingHttpClientConnectionManager cm = new PoolingHttpClientConnectionManager();
      # // Increase max total connection to 200
      cm.setMaxTotal(200);
      # // Increase default max connection per route to 20
      cm.setDefaultMaxPerRoute(20);
    end
  end
end
