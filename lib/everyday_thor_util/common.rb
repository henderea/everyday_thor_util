class Module
  def create_method(name, &block)
    self.send(:define_method, name, &block)
  end

  def dup_method(new_name, old_name)
    self.send(:alias_method, new_name, old_name)
  end
end

class Thor
  class << self
    def define_non_command(method_name, &block)
      no_commands { define_method(method_name, &block) }
    end
  end
end

module EverydayThorUtil
  class CommonHelpers
    class << self
      def print_debug_if_should(option_sym, env_sym, obj, original_method, method, args)
        print_all_debug(args, method, obj, original_method) if should_debug?(env_sym, obj, option_sym)
      end

      def print_all_debug(args, method, obj, original_method)
        print_base_debug(method, obj)
        original_method.parameters.each_with_index { |p, i| puts "#{p[1].to_s}: #{args[i]}" }
      end

      def print_base_debug(method, obj)
        puts "command: #{obj.class.basename2} #{method.gsub(/_/, '-').to_s}"
        puts "parent_options: #{obj.parent_options.inspect}"
        puts "options: #{obj.options.inspect}"
      end

      def should_debug?(env_sym, obj, option_sym)
        should_use_option_sym?(obj, option_sym) ? obj.options[option_sym.to_sym] : (env_sym && env_val_true(ENV[env_sym.to_s]))
      end

      def env_val_true(d)
        d == '1' || d == 1 || d == 'true' || d == 't'
      end

      def should_use_option_sym?(obj, option_sym)
        option_sym && (obj.options.has_key?(option_sym.to_s) || obj.options.has_key?(option_sym.to_sym))
      end

      def call_original_method(args, base, block, method_name, original_method)
        begin
          original_method.bind(base).call(*args, &block)
        rescue ArgumentError => e
          base.handle_argument_error(base.commands[method_name], e, args, original_method.arity)
        end
      end

      def define_debug_wrapper(base, env_sym, method_name, option_sym)
        base.class_eval {
          original_method = instance_method(method_name)
          define_non_command(method_name) { |*args, &block|
            EverydayThorUtil::CommonHelpers.debug_and_call_original(args, self, env_sym, method_name, option_sym, original_method, &block)
          }
        }
      end

      def debug_and_call_original(args, base, env_sym, method_name, option_sym, original_method, &block)
        print_debug_if_should(option_sym, env_sym, base, original_method, method_name, args)
        call_original_method(args, base, block, method_name, original_method)
      end
    end
  end

  module Common
    def add_debugging(base, option_sym, env_sym)
      methods = base.commands.keys - base.subcommands
      methods.each { |method_name| EverydayThorUtil::CommonHelpers.define_debug_wrapper(base, env_sym, method_name, option_sym) }
      base.subcommand_classes.values.each { |c| add_debugging(c, option_sym, env_sym) }
    end
  end
end