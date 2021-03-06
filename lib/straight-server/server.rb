module StraightServer
  class Server < Goliath::API

    use Goliath::Rack::Params
    include StraightServer::Initializer
    Faye::WebSocket.load_adapter('goliath')

    def initialize
      prepare
      StraightServer.logger.info "starting Straight Server v #{StraightServer::VERSION}"
      require_relative 'order'
      require_relative 'gateway'
      require_relative 'orders_controller'
      load_addons
      resume_tracking_active_orders!
      super
    end

    def options_parser(opts, options)
      # Even though we define that option here, it is purely for the purposes of compliance with
      # Goliath server. If don't do that, there will be an exception saying "unrecognized argument".
      # In reality, we make use of --config-dir value in the in StraightServer::Initializer and stored
      # it in StraightServer::Initializer.config_dir property. 
      opts.on('-c', '--config-dir STRING', "Directory where config files and addons are placed") do |val|
        options[:config_dir] = File.expand_path(val || ENV['HOME'] + '/.straight' )
      end
    end

    def response(env)
      # POST /gateways/1/orders   - create order
      # GET  /gateways/1/orders/1 - see order info
      #      /gateways/1/orders/1/websocket - subscribe to order status changes via a websocket

      # This will be more complicated in the future. For now it
      # just checks that the path starts with /gateways/:id/orders

      StraightServer.logger.watch_exceptions do

        # This is a client implementation example, an html page + a dart script
        # supposed to only be loaded in development.
        if Goliath.env == :development
          if env['REQUEST_PATH'] == '/'
            return [200, {}, IO.read(Initializer::GEM_ROOT + '/examples/client/client.html')]
          elsif Goliath.env == :development && env['REQUEST_PATH'] == '/client.js'
            return [200, {}, IO.read(Initializer::GEM_ROOT + '/examples/client/client.js')]
          end
        end

        @routes.each do |path, action| # path is a regexp
          return action.call(env) if env['REQUEST_PATH'] =~ path
        end
        # no block was called, means no route matched. Let's render 404
        return [404, {}, "#{env['REQUEST_METHOD']} #{env['REQUEST_PATH']} Not found"]

      end

      # Assume things went wrong, if they didn't go right
      [500, {}, "#{env['REQUEST_METHOD']} #{env['REQUEST_PATH']} Server Error"]

    end
    
  end
end
