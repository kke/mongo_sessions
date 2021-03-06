#require 'action_dispatch/middleware/session/abstract_store'
require 'rack/session/abstract/id'

module MongoSessions
  module MongoStore
    def collection
      @collection
    end

    def logger(msg)
      @logger.call("[mongo_sessions] #{msg}") unless @logger.nil?
    end
    
    def initialize(app, options = {})
      require 'mongo'
      
      unless options[:collection]
        raise "To avoid creating multiple connections to MongoDB, " +
              "the Mongo Session Store will not create it's own connection " +
              "to MongoDB - you must pass in a collection with the :collection option"
      end
      
      @collection = options[:collection].respond_to?(:call) ? options[:collection].call : options[:collection]
      @logger = options[:logger].respond_to?(:call) ? options[:logger] : nil
 
      logger "initialized with #{options.inspect}"
      super
    end
    
    def destroy(env)
      if sid = current_session_id(env)
        collection.remove({'_id' => sid})
      end
    end

    private
    def get_session(env, sid = nil)
      logger "get_session called with #{sid.inspect}"
      sid ||= generate_sid
      data = collection.find_one('_id' => sid)
      logger "get_session data: #{data.inspect.to_s}"
      [sid, data ? unpack(data['s']) : {}]
    end

    def set_session(env, sid, session_data, options = {})
      logger "set_session called with sid:#{sid.inspect} data:#{session_data.inspect}"
      sid = sid.join('&') if sid.kind_of?(Array)
      sid ||= generate_sid
      collection.update(
        {'_id' => sid}, 
        {
          '_id' => sid, 
          't' => Time.now, 
          's' => pack(session_data)
        }, 
        {:upsert => true}
      )
      sid
    end

    def destroy_session(env, sid, options = {})
      logger "destroy_session called with sid:#{sid.inspect} options:#{options.inspect}"
      collection.remove({'_id' => sid})
      options[:drop] ? nil : set_session(env, nil, {})
    end
    
    def pack(data)
      [Marshal.dump(data)].pack("m*")
    end

    def unpack(packed)
      return nil unless packed
      Marshal.load(packed.unpack("m*").first)
    end
  end
end
