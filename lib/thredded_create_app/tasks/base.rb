# frozen_string_literal: true
require 'shellwords'
require 'fileutils'
require 'erb'
require 'thredded_create_app/logging'
require 'thredded_create_app/command_error'
module ThreddedCreateApp
  module Tasks
    # @abstract
    class Base
      include ThreddedCreateApp::Logging

      def initialize(app_path:, verbose: false, **_args)
        @app_path = app_path
        @app_name = File.basename(File.expand_path(app_path))
        @verbose = verbose
        @gems = []
      end

      def summary
        self.class.name
      end

      def before_bundle
      end

      def after_bundle
      end

      protected

      def add_gem(gem_name, version: nil, groups: nil)
        log_verbose "+ gem #{gem_name}"
        @gems << [gem_name, version, groups]
      end

      def git_commit(message)
        log_info 'Commiting'
        system 'git add .'
        system 'git', 'commit', '-m', "[thredded_create_app] #{message}"
      end

      attr_reader :app_name, :app_path, :gems

      def copy(src_path, target_path)
        copy_template src_path, target_path, process_erb: false
      end

      def copy_template(src_path, target_path, process_erb: true)
        src = File.read(File.expand_path(src_path, File.dirname(__FILE__)))
        src = ERB.new(src).result(binding) if process_erb
        FileUtils.mkdir_p(File.dirname(target_path))
        File.write target_path, src
      end

      def replace(path, pattern, replacement = nil, &block)
        src = File.read(path)
        unless src.gsub! pattern, replacement, &block
          raise ThreddedCreateApp::CommandError,
                "No match found for #{pattern} in #{path}"
        end
        File.write path, src
      end

      def run_generator(generate_args)
        run "bundle exec rails g #{generate_args}#{' --quiet' unless verbose?}"
      end

      def run(*args, log: true)
        if log
          log_command args.length == 1 ? args[0] : Shellwords.shelljoin(args)
        end
        exit 1 unless system(*args)
      end

      def verbose?
        @verbose
      end
    end
  end
end
