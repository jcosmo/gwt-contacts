module Buildr
  module Checkstyle

    class << self

      # The specs for requirements
      def dependencies
        [
          'com.puppycrawl.tools:checkstyle:jar:5.4',
          'commons-cli:commons-cli:jar:1.2',
          'antlr:antlr:jar:2.7.7',
          'com.google.collections:google-collections:jar:1.0',
          'commons-beanutils:commons-beanutils-core:jar:1.8.3',
          'commons-logging:commons-logging:jar:1.1.1'
        ]
      end

      def checkstyle(configuration_file, format, output_file, source_paths, options = {})
        dependencies = (options[:dependencies] || []) + self.dependencies
        cp = Buildr.artifacts(dependencies).each(&:invoke).map(&:to_s)

        args = []
        if options[:properties_file]
          args << "-p"
          args << options[:properties_file]
        end
        args << "-c"
        args << configuration_file
        args << "-f"
        args << format
        args << "-o"
        args << output_file
        source_paths.each do |source_path|
          args << "-r"
          args << source_path
        end

        begin
          Java::Commands.java 'com.puppycrawl.tools.checkstyle.Main', *(args + [{:classpath => cp, :properties => options[:properties], :java_args => options[:java_args]}])
        rescue => e
          raise e if options[:fail_on_error]
        end
      end
    end

    class Config
      def enabled?
        File.exist?(self.configuration_file)
      end

      def html_enabled?
        File.exist?(self.style_file)
      end

      attr_writer :config_directory

      def config_directory
        @config_directory || project._(:source, :main, :etc, :checkstyle, 'checks.xml')
      end

      attr_writer :report_dir

      def report_dir
        @report_dir || project._(:reports, :checkstyle)
      end

      attr_writer :configuration_file

      def configuration_file
        @configuration_file || "#{self.config_directory}/checks.xml"
      end

      attr_writer :fail_on_error

      def fail_on_error?
        @fail_on_error.nil? ? false : @fail_on_error
      end

      attr_writer :format

      def format
        @format || 'xml'
      end

      attr_writer :xml_output_file

      def xml_output_file
        @xml_output_file || "#{self.report_dir}/checkstyle.xml"
      end

      attr_writer :html_output_file

      def html_output_file
        @html_output_file || "#{self.report_dir}/checkstyle.html"
      end

      attr_writer :style_file

      def style_file
        @style_file || "#{self.config_directory}/checkstyle-report.xsl"
      end

      attr_writer :suppressions_file

      def suppressions_file
        @suppressions_file || "#{self.config_directory}/suppressions.xml"
      end

      attr_writer :import_control_file

      def import_control_file
        @import_control_file || "#{self.config_directory}/import-control.xml"
      end

      def properties
        properties = {:basedir => self.project.base_dir}
        properties['checkstyle.suppressions.file'] = self.suppressions_file if File.exist?(self.suppressions_file)
        properties['checkstyle.import-control.file'] = self.import_control_file if File.exist?(self.import_control_file)
        properties
      end

      def source_paths
        @source_paths ||= [self.project.compile.sources, self.project.test.compile.sources]
      end

      def extra_dependencies
        @extra_dependencies ||= [self.project.compile.dependencies, self.project.test.compile.dependencies]
      end

      protected

      def initialize(project)
        @project = project
      end

      attr_reader :project

    end

    module ProjectExtension
      include Extension

      def checkstyle
        @checkstyle ||= Buildr::Checkstyle::Config.new(project)
      end

      after_define do |project|
        if project.checkstyle.enabled?
          desc "Generate checkstyle xml report."
          project.task("checkstyle:xml") do
            puts "Checkstyle: Analyzing source code..."
            mkdir_p File.dirname(project.checkstyle.xml_output_file)
            Buildr::Checkstyle.checkstyle(project.checkstyle.configuration_file,
                                          project.checkstyle.format,
                                          project.checkstyle.xml_output_file,
                                          project.checkstyle.source_paths.flatten.compact,
                                          :properties => project.checkstyle.properties,
                                          :fail_on_error => project.checkstyle.fail_on_error?,
                                          :dependencies => project.checkstyle.extra_dependencies)
          end

          if project.checkstyle.html_enabled?
            xml_task = project.task("checkstyle:xml")
            desc "Generate checkstyle html report."
            project.task("checkstyle:html" => xml_task) do
              puts "Checkstyle: Generating report"
              mkdir_p File.dirname(project.checkstyle.html_output_file)
              Buildr.ant "checkstyle" do |ant|
                ant.style :in => project.checkstyle.xml_output_file,
                          :out => project.checkstyle.html_output_file,
                          :style => project.checkstyle.style_file
              end
            end

          end
        end
      end
    end
  end
end

class Buildr::Project
  include Buildr::Checkstyle::ProjectExtension
end
