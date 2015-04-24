require 'fiddle'
require 'fiddle/import'
require 'rust/bridge'

module RailsConf
  class Analytics
    module FFI
      extend Fiddle::Importer

      dlload Dir.glob('target/release/*').map {|f| {ext: File.extname(f), file: f} }
                                         .reduce("") {|r, f| r = (f[:ext]==".so" || f[:ext]==".dylib") ? f[:file] : r }

      extern "void incr(Analytics *, Buffer *)"
      extern "Buffer * report(Analytics *)"
      extern "Analytics * analytics()"
    end

    include Rust::Bridge

    def initialize
      @analytics = FFI.analytics
    end

    def incr(string)
      FFI.incr(@analytics, Buffer.from_string(string))
    end

    def report
      Buffer.new(FFI.report(@analytics)).to_str
    end
  end
end

class AnalyticsHandler
  def initialize
    @analytics = RailsConf::Analytics.new
  end

  def call(env)
    if env["PATH_INFO"] == "/report"
      [200, {}, [@analytics.report]]
    else
      @analytics.incr(env["REQUEST_URI"])
      [200, {}, ["Success! Incremented #{env["REQUEST_URI"]}"]]
    end
  end
end

run AnalyticsHandler.new
