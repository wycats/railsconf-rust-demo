require 'fiddle'
require 'fiddle/import'
require 'rust/bridge'

module RailsConf
  class Analytics
    module FFI
      extend Fiddle::Importer

      dlload './target/release/librailsconf_demo-0410df1c134a4859.so'
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

require "uri"

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

__END__
#analytics = RailsConf.analytics
#RailsConf.increment(analytics, "https://google.com")
#RailsConf.increment(analytics, "ftp://google.com")
#RailsConf.increment(analytics, "http://google.com")
#RailsConf.increment(analytics, "http://google.com")
#RailsConf.increment(analytics, "http://google.co")

#RailsConf.report(analytics)

Benchmark.ips do |x|
  x.report("Ruby") do
    analytics = Analytics.new
    1_000.times do
      analytics.incr("http://google.com/hello?foo=1")
      analytics.incr("http://google.com/hello?foo=1")
      analytics.incr("http://google.co/goodbye")
    end
  end

  x.report("Rust") do
    analytics = RailsConf.analytics
    1_000.times do
      RailsConf.increment(analytics, "http://google.com/hello?foo=1")
      RailsConf.increment(analytics, "http://google.com/hello?foo=1")
      RailsConf.increment(analytics, "http://google.co/goodbye")
    end
  end
end

class Analytics
  def initialize
    @endpoints = Hash.new(0)
    @schemes = Hash.new(0)
    @hosts = Hash.new(0)
    @total = 0
  end

  def incr(raw_url)
    url = URI(raw_url)
    @endpoints[raw_url] += 1
    @schemes[url.scheme] += 1
    @hosts[url.host] += 1
    @total += 1
  end
end
