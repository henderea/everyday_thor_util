require 'io/console'
class Thor
  module Shell
    class Basic
      def print_wrapped(message, options = {})
        indent = options[:indent] || 0
        width = terminal_width - indent
        paras = message.split("\n\n")
        min_space_length = paras.map{|para| para.gsub(/^(\s*)\S.*$/, '\1').length }.min

        paras.map! do |unwrapped|
          unwrapped.gsub(/(^|\005)([ ]+)/) { "#{$1}#{"\0" * ($2.length - min_space_length)}" }.strip.tr("\n", " ").squeeze(" ").gsub(/.{1,#{width}}(?:\s|\Z)/) { ($& + 5.chr).gsub(/\n\005/, "\n").gsub(/\005/, "\n").gsub(/\0/, ' ') }
        end

        paras.each do |para|
          para.split("\n").each do |line|
            stdout.puts line.insert(0, " " * indent)
          end
          stdout.puts unless para == paras.last
        end
      end
      def dynamic_width
        IO.console.winsize[1]
      end
    end
  end
end