require 'everyday_thor_util/thor-fix'
require 'everyday_thor_util/common'
require 'everyday-plugins'
include EverydayPlugins
require 'thor'

module EverydayThorUtil
  class SubCommandTypes
    extend PluginType
    extend Plugin
    extend TypeHelper
    extend EverydayThorUtil::Common

    class << self
      def def_types(command_array_symbol, flag_symbol, command_symbol, helper_symbol = nil)
        register_variable command_array_symbol, []
        register_flag_type(flag_symbol)
        register_command_type(command_array_symbol, command_symbol, flag_symbol, helper_symbol)
        register_helper_type(helper_symbol) unless helper_symbol.nil?
      end

      def register_flag_type(flag_symbol)
        register_type(flag_symbol) { |list, parent_class, parent, has_children|
          EverydayThorUtil::SubCommandHelpers.filter_list(list, parent).each { |v|
            name, opts = EverydayThorUtil::SubCommandHelpers.map_flag_opts(v)
            has_children ? parent_class.class_option(name, opts) : parent_class.option(name, opts)
          }
        }
      end

      def register_command_type(command_array_symbol, command_symbol, flag_symbol, helper_symbol)
        register_type(command_symbol) { |list, parent_class, parent|
          EverydayThorUtil::SubCommandHelpers.setup_root(flag_symbol, helper_symbol, parent, parent_class)
          EverydayThorUtil::SubCommandHelpers.filter_list(list, parent).each { |v|
            aliases, desc, id, long_desc, name, short_desc = EverydayThorUtil::SubCommandHelpers.extract_command_info(v)
            id && name &&
                ((list.any? { |v2| v2[:options][:parent] == id } && EverydayThorUtil::SubCommandHelpers.create_cmd_class_and_aliases(aliases, command_array_symbol, command_symbol, desc, flag_symbol, helper_symbol, id, long_desc, name, parent_class, short_desc)) ||
                    (v[:block] && EverydayThorUtil::SubCommandHelpers.create_cmd_method_and_aliases(aliases, desc, flag_symbol, id, long_desc, name, parent_class, short_desc, v)))
          }
        }
      end

      def register_helper_type(helper_symbol)
        register_type(helper_symbol) { |list, parent_class, parent|
          EverydayThorUtil::SubCommandHelpers.filter_list(list, parent) { |v| v[:options][:global] }.each { |v| parent_class.no_commands { parent_class.create_method v[:options][:name].to_sym, &v[:block] } if v[:block] }
        }
      end

      def def_helper(helper_symbol, which_helper, method_name = nil, global = true, parent = nil)
        case (which_helper)
          when :print_info
            EverydayThorUtil::SubCommandHelpers.register_print_info_helper(global, helper_symbol, method_name, parent)
          else
            puts "Unknown helper #{which_helper}"
        end
      end
    end
  end

  class SubCommandHelpers
    class << self
      def map_flag_opts(v)
        opts = {}
        name = v[:options][:name].to_sym
        copy_opts(opts, v, :desc, :banner, :default, :type, :aliases)
        copy_opt(opts, v, :required, !v[:options][:default])
        return name, opts
      end

      def copy_opts(opts, v, *opt_name)
        opt_name.each { |n| copy_opt(opts, v, n) }
      end

      def copy_opt(opts, v, opt_name, extra_condition = true)
        opts[opt_name] = v[:options][opt_name] if v[:options][opt_name] && extra_condition
      end

      def create_cmd_class_and_aliases(aliases, command_array_symbol, command_symbol, desc, flag_symbol, helper_symbol, id, long_desc, name, parent_class, short_desc)
        command_ids = Plugins.get_var command_array_symbol
        unless command_ids.include?(id)
          command_ids << id
          Plugins.set_var command_array_symbol, command_ids
          create_command_class(command_symbol, desc, flag_symbol, helper_symbol, id, long_desc, name, parent_class, short_desc)
          aliases.each { |a| create_command_class(command_symbol, desc, flag_symbol, helper_symbol, id, long_desc, a, parent_class, short_desc.gsub(/^\S+(?=\s|$)/, a.gsub(/_/, '-'))) } if aliases
        end
        true
      end

      def create_cmd_method_and_aliases(aliases, desc, flag_symbol, id, long_desc, name, parent_class, short_desc, v)
        setup_command(desc, flag_symbol, id, long_desc, parent_class, short_desc)
        parent_class.create_method(name.to_sym, &v[:block])
        aliases.each { |a|
          setup_command(desc, flag_symbol, id, long_desc, parent_class, short_desc)
          parent_class.dup_method a.to_sym, name.to_sym
        } if aliases
        true
      end

      def extract_command_info(v)
        return v[:options][:aliases], v[:options][:desc], v[:options][:id], v[:options][:long_desc], v[:options][:name], v[:options][:short_desc]
      end

      def filter_list(list, parent, &extra)
        list.select { |v| v[:options][:parent] == parent || (extra && extra.call(v)) }
      end

      def setup_root(flag_symbol, helper_symbol, parent, parent_class)
        Plugins.get helper_symbol, parent_class, nil unless parent || helper_symbol.nil?
        Plugins.get flag_symbol, parent_class, nil, true unless parent
      end

      def create_command_class(command_symbol, desc, flag_symbol, helper_symbol, id, long_desc, name, parent_class, short_desc)
        command_class = Class.new(Thor)
        command_class.namespace name
        Plugins.get helper_symbol, command_class, id unless helper_symbol.nil?
        Plugins.get flag_symbol, command_class, id, true
        Plugins.get command_symbol, command_class, id
        setup_command(desc, flag_symbol, id, long_desc, parent_class, short_desc)
        parent_class.subcommand name, command_class
      end

      def setup_command(desc, flag_symbol, id, long_desc, parent_class, short_desc)
        Plugins.get flag_symbol, parent_class, id, false
        parent_class.desc short_desc, desc if short_desc && desc
        parent_class.long_desc long_desc if long_desc
      end

      def register_print_info_helper(global, helper_symbol, method_name, parent)
        register(helper_symbol, name: (method_name || 'print_info'), global: global, parent: parent) { |meth, &eval_block|
          meth_obj = self.method(meth)
          puts "command: #{self.class.basename2} #{meth.to_s}"
          puts "parent_options: #{parent_options.inspect}"
          puts "options: #{options.inspect}"
          meth_obj.parameters.each { |p| puts "#{p[1].to_s}: #{eval_block.call(p[1].to_s)}" } if eval_block
        }
      end
    end
  end
end
