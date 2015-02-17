class Module
  def create_method(name, &block)
    self.send(:define_method, name, &block)
  end

  def dup_method(new_name, old_name)
    self.send(:alias_method, new_name, old_name)
  end
end

module EverydayThorUtil
  class CommonHelpers
    class << self
      def print_debug(option_sym, env_sym, obj, original_method, method, args)
        if should_debug?(env_sym, obj, option_sym)
          puts "command: #{obj.class.basename2} #{method.gsub(/_/, '-').to_s}"
          puts "parent_options: #{obj.parent_options.inspect}"
          puts "options: #{obj.options.inspect}"
          original_method.parameters.each_with_index { |p, i| puts "#{p[1].to_s}: #{args[i]}" }
        end
      end

      def should_debug?(env_sym, obj, option_sym)
        if option_sym && (obj.options.has_key?(option_sym.to_s) || obj.options.has_key?(option_sym.to_sym))
          obj.options[option_sym.to_sym]
        elsif env_sym
          d = ENV[env_sym.to_s]
          d == '1' || d == 1 || d == 'true' || d == 't'
        end
      end

      def call_original_method(args, base, block, method_name, original_method)
        begin
          original_method.bind(self).call(*args, &block)
        rescue ArgumentError => e
          base.handle_argument_error(base.commands[method_name], e, args, original_method.arity)
        end
      end
    end
  end

  module Common
    def add_debugging(base, option_sym, env_sym)
      methods = base.commands.keys - base.subcommands
      base.class_eval {
        methods.each { |method_name|
          original_method = instance_method(method_name)
          no_commands {
            define_method(method_name) { |*args, &block|
              EverydayThorUtil::CommonHelpers.print_debug(option_sym, env_sym, self, original_method, __method__, args)
              EverydayThorUtil::CommonHelpers.call_original_method(args, base, block, method_name, original_method)
            }
          }
        }
      }
      base.subcommand_classes.values.each { |c| add_debugging(c, option_sym, env_sym) }
    end
  end
end