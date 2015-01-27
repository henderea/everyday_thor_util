require 'everyday_thor_util/thor-fix'

class Module
  def create_method(name, &block)
    self.send(:define_method, name, &block)
  end

  def dup_method(new_name, old_name)
    self.send(:alias_method, new_name, old_name)
  end
end

module EverydayThorUtil
  module BuilderBuildItems
    class BuilderCommand
      def initialize(parent = nil, options = {}, &block)
        @aliases = options.delete(:aliases) if options.has_key?(:aliases) && !parent.nil?
        @parent = parent
        @options = options
        @body   = block
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
      if p.parent.nil?
        build_flags(p, pc, true)
        build_helpers(p, pc)
      end
      p.commands.commands.each { |cn, c|
        short_desc = c.options[:short_desc]
        desc      = c.options[:desc]
        long_desc = c.options[:long_desc]
        aliases   = c.aliases
        if !c.leaf?
          cc = Class.new(Thor)
          cc.namespace cn.to_s
          build_helpers(c, cc)
          build_flags(c, cc, true)
          build_recurse(c, cc)
          build_flags(c, pc, false)
          pc.desc short_desc, desc if short_desc && desc
          pc.long_desc long_desc if long_desc
          pc.subcommand cn, cc
          aliases.each { |an|
            cc2 = Class.new(Thor)
            cc2.namespace an
            build_helpers(c, cc2)
            build_flags(c, cc2, true)
            build_recurse(c, cc2)
            build_flags(c, pc, false)
            pc.desc short_desc.gsub(/^\S+(?=\s|$)/, an.gsub(/_/, '-')), desc if short_desc && desc
            pc.long_desc long_desc if long_desc
            pc.subcommand an, cc2
          } if aliases && !aliases.empty?
        elsif c.body
          build_flags(c, pc, false)
          pc.desc short_desc, desc if short_desc && desc
          pc.long_desc long_desc if long_desc
          pc.create_method(cn.to_sym, &c.body)
          aliases.each { |an|
            build_flags(c, pc, false)
            pc.desc short_desc.gsub(/^\S+(?=\s|$)/, an.gsub(/_/, '-')), desc if short_desc && desc
            pc.long_desc long_desc if long_desc
            pc.dup_method an.to_sym, cn.to_sym
          } if aliases
        end
      }
    end

    def add_debugging(base, option_sym, env_sym)
      methods = base.commands.keys - base.subcommands
      base.class_eval {
        methods.each { |method_name|
          original_method = instance_method(method_name)
          no_commands {
            define_method(method_name) { |*args, &block|
              debug = if option_sym && (options.has_key?(option_sym.to_s) || options.has_key?(option_sym.to_sym))
                        options[option_sym.to_sym]
                      elsif env_sym
                        d = ENV[env_sym.to_s]
                        d == '1' || d == 1 || d == 'true' || d == 't'
                      end
              if debug
                puts "command: #{self.class.basename2} #{__method__.gsub(/_/, '-').to_s}"
                puts "parent_options: #{parent_options.inspect}"
                puts "options: #{options.inspect}"
                original_method.parameters.each_with_index { |p, i| puts "#{p[1].to_s}: #{args[i]}" }
              end
              begin
                original_method.bind(self).call(*args, &block)
              rescue ArgumentError => e
                base.handle_argument_error(base.commands[method_name], e, args, original_method.arity)
              end
            }
          }
        }
      }
      base.subcommand_classes.values.each { |c| add_debugging(c, option_sym, env_sym) }
    end

    private :build_recurse
  end
end