require 'everyday_thor_util/thor-fix'
require 'everyday_thor_util/common'

module EverydayThorUtil
  module BuilderBuildItems
    class BuilderCommand
      def initialize(parent = nil, options = {}, &block)
        @aliases = options.delete(:aliases) if options.has_key?(:aliases) && !parent.nil?
        @parent  = parent
        @options = options
        @body    = block
      end

      def parent
        @parent
      end

      def body
        @body
      end

      def options
        @options
      end

      def define(&block)
        block.call(self.commands, self.flags, self.helpers)
      end

      def aliases
        @aliases ||= []
      end

      def commands
        @commands ||= EverydayThorUtil::BuilderBuildLists::BuilderCommands.new(self)
      end

      def flags
        @flags ||= EverydayThorUtil::BuilderBuildLists::BuilderFlags.new(self)
      end

      def helpers
        @helpers ||= EverydayThorUtil::BuilderBuildLists::BuilderHelpers.new(self)
      end

      def leaf?
        self.commands.commands.empty? && self.helpers.helpers.empty?
      end

      def [](name)
        if self.commands.has_key?(name)
          self.commands[name]
        elsif self.helpers.has_key?(name)
          self.helpers[name]
        elsif self.flags.has_key?(name)
          self.flags[name]
        else
          nil
        end
      end

      def []=(name, obj)
        if obj.is_a?(Hash)
          self.flags[name] = obj
        elsif obj.is_a?(BuilderCommand)
          self.commands[name] = obj
        elsif obj.is_a?(Proc)
          self.helpers[name] = obj
        end
      end
    end
    class BuilderGlobal
      def helpers
        @helpers ||= EverydayThorUtil::BuilderBuildLists::BuilderHelpers.new(self)
      end
    end
  end
  module BuilderBuildLists
    class BuilderHelpers
      def initialize(parent)
        @parent  = parent
        @helpers = {}
      end

      def helpers
        @helpers
      end

      def [](name)
        @helpers[name.to_sym]
      end

      def []=(name, body)
        if body.nil?
          self.delete(name)
          nil
        else
          @parent.commands.delete(name) if @parent.respond_to?(:commands) && @parent.commands.has_key?(name)
          @helpers[name.to_sym] = body
        end
      end

      def has_key?(name)
        @helpers.has_key?(name.to_sym)
      end

      def delete(name)
        @helpers.delete(name.to_sym)
      end
    end
    class BuilderFlags
      def initialize(parent)
        @parent = parent
        @flags  = {}
      end

      def flags
        @flags
      end

      def [](name)
        @flags[name.to_sym]
      end

      def []=(name, flag)
        if flag.nil?
          self.delete(name)
          nil
        else
          @flags[name.to_sym] = flag
        end
      end

      def has_key?(name)
        @flags.has_key?(name.to_sym)
      end

      def delete(name)
        @flags.delete(name.to_sym)
      end
    end
    class BuilderCommands
      def initialize(parent)
        @parent   = parent
        @commands = {}
      end

      def commands
        @commands
      end

      def [](name)
        @commands[name.to_sym]
      end

      def []=(name, command)
        if command.nil?
          delete(name)
          nil
        else
          @parent.helpers.delete(name) if @parent.helpers.has_key?(name)
          @commands[name.to_sym] = EverydayThorUtil::BuilderBuildItems::BuilderCommand.new(@parent, command.options, &command.body)
        end
      end

      def has_key?(name)
        @commands.has_key?(name.to_sym)
      end

      def delete(name)
        @commands.delete(name.to_sym)
      end
    end
  end
  module Builder
    include EverydayThorUtil::Common

    def global
      @global ||= EverydayThorUtil::BuilderBuildItems::BuilderGlobal.new
    end

    def root_command
      @root_command ||= EverydayThorUtil::BuilderBuildItems::BuilderCommand.new
    end

    def flag(opts = {})
      opts
    end

    def command(options = {}, &block)
      EverydayThorUtil::BuilderBuildItems::BuilderCommand.new(nil, options, &block)
    end

    def build!
      rc = Class.new(Thor)
      build_recurse(self.root_command, rc)
      rc
    end

    def build_helpers(p, pc)
      self.global.helpers.helpers.each { |hn, h| pc.no_commands { pc.create_method(hn.to_sym, &h) } }
      p.helpers.helpers.each { |hn, h| pc.no_commands { pc.create_method(hn.to_sym, &h) } }
    end

    def build_flags(p, pc, has_children)
      p.flags.flags.each { |fn, f| has_children ? pc.class_option(fn.to_sym, f) : pc.option(fn.to_sym, f) }
    end

    def build_recurse(p, pc)
      setup_root(p, pc) if p.parent.nil?
      p.commands.commands.each { |cn, c|
        aliases, desc, long_desc, short_desc = extract_command_info(c)
        handle_command_class(c, pc, cn, aliases, desc, long_desc, short_desc) ||
            handle_command_method(c, pc, cn, aliases, desc, long_desc, short_desc)
      }
    end

    def setup_root(p, pc)
      build_flags(p, pc, true)
      build_helpers(p, pc)
    end

    def setup_command(c, pc, desc, long_desc, short_desc)
      build_flags(c, pc, false)
      pc.desc short_desc, desc if short_desc && desc
      pc.long_desc long_desc if long_desc
    end

    def handle_command_class(c, pc, cn, aliases, desc, long_desc, short_desc)
      !c.leaf? && create_cmd_class_and_aliases(c, pc, cn, aliases, desc, long_desc, short_desc)
    end

    def handle_command_method(c, pc, cn, aliases, desc, long_desc, short_desc)
      c.body && create_cmd_method_and_aliases(c, pc, cn, aliases, desc, long_desc, short_desc)
    end

    def create_cmd_class_and_aliases(c, pc, cn, aliases, desc, long_desc, short_desc)
      create_command_class(c, pc, cn, desc, long_desc, short_desc)
      aliases.each { |an| create_command_class(c, pc, an, desc, long_desc, short_desc.gsub(/^\S+(?=\s|$)/, an.gsub(/_/, '-'))) } if aliases && !aliases.empty?
      true
    end

    def create_cmd_method_and_aliases(c, pc, cn, aliases, desc, long_desc, short_desc)
      setup_command(c, pc, desc, long_desc, short_desc)
      pc.create_method(cn.to_sym, &c.body)
      aliases.each { |an|
        setup_command(c, pc, desc, long_desc, short_desc)
        pc.dup_method an.to_sym, cn.to_sym
      } if aliases
      true
    end

    def create_command_class(c, pc, cn, desc, long_desc, short_desc)
      cc = Class.new(Thor)
      cc.namespace cn.to_s
      build_helpers(c, cc)
      build_flags(c, cc, true)
      build_recurse(c, cc)
      setup_command(c, pc, desc, long_desc, short_desc)
      pc.subcommand cn, cc
    end

    def extract_command_info(c)
      short_desc = c.options[:short_desc]
      desc       = c.options[:desc]
      long_desc  = c.options[:long_desc]
      aliases    = c.aliases
      return aliases, desc, long_desc, short_desc
    end

    private :build_helpers, :build_flags, :build_recurse, :setup_root, :setup_command, :handle_command_class, :handle_command_method, :create_command_class, :extract_command_info
  end
end