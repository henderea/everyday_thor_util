class Module
  def create_method(name, &block)
    self.send(:define_method, name, &block)
  end

  def dup_method(new_name, old_name)
    self.send(:alias_method, new_name, old_name)
  end
end

module EverydayThorUtil
  module Common
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
  end
end