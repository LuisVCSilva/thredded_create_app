# frozen_string_literal: true
require 'thredded_create_app/command_error'
require 'thredded_create_app/generator'
require 'thredded_create_app/logging'

require 'highline'
module ThreddedCreateApp
  class CLI
    include ThreddedCreateApp::Logging

    DEFAULTS = {
      auto_confirm: false,
      verbose: false,
      install_gem_bundler_rails: true,
      start_server: true,
      # The simple_form option is currently broken.
      # Fixed by https://github.com/tigrish/devise-i18n/pull/139 (merged)
      # TODO: Set the default to true once a new version devise-i18n is released
      simple_form: false
    }.freeze

    def self.start(argv)
      new(argv).start
    end

    def initialize(argv)
      @argv = argv
    end

    def start
      auto_output_coloring do
        begin
          run
        rescue OptionParser::ParseError, ArgvError => e
          error e.message, 64
        rescue ThreddedCreateApp::CommandError => e
          begin
            error e.message, 78
          ensure
            log_verbose e.backtrace * "\n"
          end
        rescue Errno::EPIPE
          exit 1
        end
      end
    rescue ExecutionError => e
      exit e.exit_code
    end

    private

    def run # rubocop:disable Metrics/AbcSize
      options = optparse
      generator = ThreddedCreateApp::Generator.new(options)
      log_info 'Will do the following:'
      log_info generator.summary
      exit unless options[:auto_confirm] || agree?
      generator.generate
      log_stderr Term::ANSIColor.bold Term::ANSIColor.bright_green <<~TEXT
        All done! 🌟
      TEXT
      start_app_server!(options[:app_path]) if options[:start_server]
    end

    def start_app_server!(app_path)
      log_info 'Changing directory and starting the app server'
      command = "cd #{Shellwords.escape(app_path)} && " \
        'bundle exec rails s'
      log_command command
      Bundler.with_clean_env { exec command }
    end

    # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/BlockLength
    def optparse
      argv = @argv.dup
      argv << '--help' if argv.empty?
      options = DEFAULTS.dup
      positional_args = OptionParser.new(
        "Usage: #{program_name} #{Term::ANSIColor.bold 'APP_PATH'}"
      ) do |op|
        default_text = -> (option) { " (default: #{DEFAULTS[option]})" }

        op.on('-y', 'Auto-confirm all prompts') do
          options[:auto_confirm] = true
        end
        op.on('-v', '--version', 'Print the version') do
          puts ThreddedCreateApp::VERSION
          exit
        end
        op.on('--verbose', 'Verbose output') do
          options[:verbose] = @verbose = true
        end
        op.on('--[no-]simple-form', 'Use simple_form' +
            default_text[:simple_form]) do |v|
          options[:simple_form] = v
        end
        op.on('--[no-]install-gem-bundler-rails',
              'Run `gem update --system and `gem install bundler rails`' +
                  default_text[:simple_form]) do |v|
          options[:install_gem_bundler_rails] = v
        end
        op.on('--[no-]start-server', 'Start the app server' +
            default_text[:start_server]) do |v|
          options[:start_server] = v
        end
        op.on('-h', '--help', 'Show this message') do
          STDERR.puts op
          exit
        end
        op.separator Term::ANSIColor.bright_blue <<-TEXT

For more information, see the readme at:
    #{File.expand_path('../../README.md', File.dirname(__FILE__))}
    https://github.com/thredded/thredded_create_app
TEXT
      end.parse!(argv)
      if positional_args.length != 1
        raise ArgvError, 'Expected 1 positional argument, ' \
                        "got #{positional_args.length}."
      end
      options.update(app_path: argv[0])
      options
    end
    # rubocop:enable Metrics/AbcSize,Metrics/MethodLength,Metrics/BlockLength

    def error(message, exit_code)
      log_error message
      raise ExecutionError.new(message, exit_code)
    end

    def auto_output_coloring(coloring = STDOUT.isatty)
      coloring_was             = Term::ANSIColor.coloring?
      Term::ANSIColor.coloring = coloring
      HighLine.use_color       = coloring
      yield
    ensure
      HighLine.use_color       = coloring_was
      Term::ANSIColor.coloring = coloring_was
    end

    def agree?
      ::HighLine.new.agree(
        Term::ANSIColor.bold(Term::ANSIColor.bright_yellow('Proceed? [y/n]')),
        true
      )
    end

    def verbose?
      @verbose
    end

    class ArgvError < StandardError
    end

    class ExecutionError < RuntimeError
      attr_reader :exit_code

      def initialize(message, exit_code)
        super(message)
        @exit_code = exit_code
      end
    end
  end
end
