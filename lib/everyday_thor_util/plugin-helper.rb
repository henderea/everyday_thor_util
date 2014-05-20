require 'everyday_thor_util/thor-fix'
require 'everyday-plugins'
include EverydayPlugins
require 'thor'

class Module
  def create_method(name, &block)
    self.send(:define_method, name, &block)
  end

  def dup_method(new_name, old_name)
    self.send(:alias_method, new_name, old_name)
  end
end

module EverydayThorUtil
  class SubCommandTypes
    extend PluginType
    extend Plugin
    extend TypeHelper

    class << self
      def def_types(command_array_symbol, flag_symbol, command_symbol, helper_symbol = nil)
        register_variable command_array_symbol, []

        register_type(flag_symbol) { |list, parent_class, parent, has_children|
          filtered_list = list.select { |v| v[:options][:parent] == parent }
          filtered_list.each { |v|
            opts            = {}
            name            = v[:options][:name].to_sym
            opts[:desc]     = v[:options][:desc] if v[:options][:desc]
            opts[:banner]   = v[:options][:banner] if v[:options][:banner]
            opts[:required] = v[:options][:required] if v[:options][:required] && !v[:options][:default]
            opts[:default]  = v[:options][:default] if v[:options][:default]
            opts[:type]     = v[:options][:type] if v[:options][:type]
            opts[:aliases]  = v[:options][:aliases] if v[:options][:aliases]
            has_children ? parent_class.class_option(name, opts) : parent_class.option(name, opts)
          }
        }

        register_type(command_symbol) { |list, parent_class, parent|
          Plugins.get helper_symbol, parent_class, nil unless parent || helper_symbol.nil?
          Plugins.get flag_symbol, parent_class, nil, true unless parent
          filtered_list = list.select { |v| v[:options][:parent] == parent || nil }
          filtered_list.each { |v|
            id         = v[:options][:id]
            short_desc = v[:options][:short_desc]
            desc       = v[:options][:desc]
            long_desc  = v[:options][:long_desc]
            name       = v[:options][:name]
            aliases    = v[:options][:aliases]
            if id && name
              has_children = list.any? { |v2| v2[:options][:parent] == id }
              if has_children
                command_ids = Plugins.get_var command_array_symbol
                unless command_ids.include?(id)
                  command_ids << id
                  Plugins.set_var command_array_symbol, command_ids
                  command_class = Class.new(Thor)
                  command_class.namespace name
                  Plugins.get helper_symbol, command_class, id unless helper_symbol.nil?
                  Plugins.get flag_symbol, command_class, id, true
                  Plugins.get command_symbol, command_class, id
                  Plugins.get flag_symbol, parent_class, id, false
                  parent_class.desc short_desc, desc if short_desc && desc
                  parent_class.long_desc long_desc if long_desc
                  parent_class.subcommand name, command_class
                  aliases.each { |a|
                    command_class2 = Class.new(Thor)
                    command_class2.namespace a
                    Plugins.get flag_symbol, command_class2, id, true
                    Plugins.get command_symbol, command_class2, id
                    Plugins.get flag_symbol, parent_class, id, false
                    parent_class.desc short_desc.gsub(/^#{name}/, a), desc if short_desc && desc
                    parent_class.long_desc long_desc if long_desc
                    parent_class.subcommand a, command_class2
                  } if aliases
                end
              elsif v[:block]
                Plugins.get flag_symbol, parent_class, id, false
                parent_class.desc short_desc, desc if short_desc && desc
                parent_class.long_desc long_desc if long_desc
                parent_class.create_method(name.to_sym, &v[:block])
                aliases.each { |a|
                  Plugins.get flag_symbol, parent_class, id, false
                  parent_class.desc short_desc.gsub(/^#{name}/, a), desc if short_desc && desc
                  parent_class.long_desc long_desc if long_desc
                  parent_class.dup_method a.to_sym, name.to_sym
                } if aliases
              end
            end
          }
        }

        unless helper_symbol.nil?
          register_type(helper_symbol) { |list, parent_class, parent|
            filtered_list = list.select { |v| v[:options][:parent] == parent || v[:options][:global] }
            filtered_list.each { |v|
              name = v[:options][:name].to_sym
              parent_class.no_commands { parent_class.create_method name, &v[:block] } if v[:block]
            }
          }
        end
      end

      def def_helper(helper_symbol, which_helper, method_name = nil, global = true, parent = nil)
        case (which_helper)
          when :print_info
            register(helper_symbol, name: (method_name || 'print_info'), global: global, parent: parent) { |meth, &eval_block|
              meth_obj = self.method(meth)
              puts "command: #{self.class.basename2} #{meth.to_s}"
              puts "parent_options: #{parent_options.inspect}"
              puts "options: #{options.inspect}"
              meth_obj.parameters.each { |p| puts "#{p[1].to_s}: #{eval_block.call(p[1].to_s)}" } if eval_block
            }
          else
            puts "Unknown helper #{which_helper}"
        end
      end

      def add_debugging(base, option_sym, env_sym)
        methods = base.commands.keys - base.subcommands
        base.class_eval {
          methods.each { |method_name|
            original_method = instance_method(method_name)
            no_commands {
              define_method(method_name) { |*args, &block|
                debug = if options.has_key?(option_sym.to_s) || options.has_key?(option_sym.to_sym)
                          options[option_sym.to_sym]
                        else
                          d = ENV[env_sym.to_s]
                          d == '1' || d == 1 || d == 'true' || d == 't'
                        end
                if debug
                  puts "command: #{self.class.basename2} #{__method__.to_s}"
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
end
