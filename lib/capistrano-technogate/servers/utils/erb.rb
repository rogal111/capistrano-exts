# encoding: utf-8

require 'erb'

module Capistrano
  module TechnoGate
    module Erb
      def render
        sanity_check

        erb_template = ::ERB.new(File.read(@template))
        erb_template.result(binding)
      end
    end
  end
end