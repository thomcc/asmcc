require 'optparse'
require 'tempfile'

CXX_TEMPLATE = <<-CODE_EOF
#include <cinttypes>
#include <cmath>
#include <cstddef>
#include <cstring>
#include <climits>

uint64_t factorial(uint64_t arg) {
  if (arg <= 1) return 1;
  return arg * factorial(arg - 1);
}
CODE_EOF


C_TEMPLATE = <<-CODE_EOF
#include <inttypes.h>
#include <math.h>
#include <stddef.h>
#include <string.h>
#include <limits.h>
#include <stdbool.h>

uint64_t factorial(uint64_t arg) {
  if (arg <= 1) return 1;
  return arg * factorial(arg - 1);
}
CODE_EOF


class AsmCC
  def initialize
    @parsed_settings = false
    @custom_template = nil
    @warnings = %W[all effc++]
    @includes = %W[#{Dir.pwd} #{Dir.pwd}/include /usr/local/include]
    @opt_level = '3'

    @input = nil
    @output = nil

    @defines = []
    @undefs = []

    @enable_exns = false
    @enable_rtti = false

    @accurate_fp = true

    @output = nil

    @arch = 'native'

    @xflags = []

    @force_bits = nil

    @verbose_asm = true

    @edit_asm = false
    @show_encoding = false
    @debug = false
    @demangle = true
    @emit_llvm = false

    @combined_output = false

    @std = "c++1y"
    @lang = :"c++"
  end

  def parse_settings!
    return self if @parsed_settings
    @parsed_settings = true
    OptionParser.new do |opts|
      opts.banner = 'Usage: asmcc [options]'
      opts.separator ''
      opts.separator 'Options:'

      opts.on('-g', '--debug-info', 'Include debugging info?') do
        @debug = true
      end

      opts.on('-O', '--opt-level 0123s', '01234s'.split(''), 'Set optimization level (3 by default).') do |v|
        @opt_level = v
      end

      opts.on('-l', '--lang LANG', [:"c++", :c, :"objective-c", :"objective-c++"],
              'Set language. Defaults to c++.',
              '  Must be one of ["c++", "c", "objective-c", "objective-c++"]') do |l|
        @lang = l
      end

      opts.on('-s', '--std STD', String, 'Use the specified standard. Defaults to c++1y for c++/objc++, c11 for c/objc.') do |std|
        @std = std
      end

      opts.on('-L', '--emit-llvm', 'Emit LLVM IR. (disables --show-encoding).') do |v|
        @emit_llvm = true
      end

      opts.on('-F', '--[no-]fast-math', 'Prefer speed to accuracy for floating point? (off by default).') do |b|
        @accurate_fp = !b
      end

      opts.on('-a', '--arch ARCH', String, 'Specify -march flag value (default is "native").') do |arch|
        @arch = arch
      end

      opts.on('--m32', 'Force 32 bit compilation.') do
        @force_bits = 32
      end

      opts.on('--m64', 'Force 64 bit compilation.') do
        @force_bits = 64
      end

      opts.on('-X', '--Xcc f,l,a,g,s', Array, 'Pass extra flags to the compiler.') do |fs|
        @xflags += fs
      end

      opts.on('-e', '--[no-]exceptions', 'Enable exceptions. Disabled by default.') do |e|
        @enable_exns = e
      end

      opts.on('-r', '--[no-]rtti', 'Enable runtime type info. Disabled by default.') do |r|
        @enable_rtti = r
      end

      opts.on('-E', '--edit-result', 'Open output file in editor.') do
        @edit_asm = true
      end

      opts.on('--no-verbose-asm', 'Disable verbose assembly output.') do
        @verbose_asm = false
      end

      opts.on('-D', '--define l,i,s,t', Array, 'Pass -Dl -Di -Ds -Dt to the compiler.') do |ds|
        @defines += ds
      end

      opts.on('-U', '--undef l,i,s,t', Array, 'Pass -Ul -Ui -Us -Ut to the compiler (overrides -D).') do |us|
        @undefs += us
      end

      opts.on('-W', '--warn w0,w1,etc', Array, 'Specify warnings to use (defaults to Wall,Wextra).') do |ws|
        @warnings = ws
      end

      opts.on('-I', '--include d,i,r,s', Array, 'Extra -I include directories.',
                                                '  Automatically contains "`pwd`,`pwd`/include,/usr/local/include".') do |is|
        @includes += is
      end

      opts.on('-S', '--show-encoding', 'Show encoding?') do
        @show_encoding = true
      end

      opts.on('-C', '--combined-output', 'Output both the source fed into the compiler and the generated assembly') do
        @combined_output = true
      end

      opts.on('-o', '--out FILE', 'Output to FILE instead of stdout.') do |f|
        @output = f
      end

      opts.on('-i', '--input FILE', 'Use FILE as input instead of opening from the editor.') do |f|
        if File.exist? f
          @input = f
        else
          abort "No such file: \"#{f}\""
        end
      end

      opts.on('-T', '--template FILE', String, 'Use FILE for template') do |f|
        begin
          @custom_template = IO.read(f)
        rescue
          puts "Warning: Unable to read template file: \"#{f}\", ignoring -T option..."
          @custom_template = nil
        end
      end

      opts.on('--[no-]demangle', 'Demangle C++ identifiers (requires `c++filt`, ignored for c and objc)') do |d|
        @demangle = false
      end

      opts.on('-v', '--verbose', 'Pass -v to the compiler') do
        @xflags << '-v'
      end

      opts.on('-h', '--help', 'Show this message') do
        puts opts
        exit
      end

    end.parse!

    @show_encoding = false if @emit_llvm

    unless is_cxx?
      if @std.include? '++'
        @std = @std.include?('gnu') ? 'gnu11' : 'c11'
      end
    end

    self
  end

  def try_again? prompt, default
    print "#{prompt} #{default ? '[Y/n]' : '[y/N]'}:"
    result = gets.strip
    if result.empty?
      default
    elsif result[0] == 'Y' || result[0] == 'y'
      true
    elsif result[0] == 'N' || result[0] == 'n'
      false
    else
      default
    end
  end

  def edit_file fpath
    system(ENV['VISUAL'] || ENV['EDITOR'] || '/usr/bin/nano', fpath)
  end

  def is_darwin?
    `uname`.strip == 'Darwin'
  end

  def is_cxx?
    @lang == :"c++" or @lang == :"objective-c++"
  end

  def is_objc?
    @lang == :"objective-c" or @lang == :"objective-c++"
  end

  def file_extension
    case @lang
      when :"c"
        ".c"
      when :"c++"
        ".cpp"
      when :"objective-c"
        ".m"
      when :"objective-cpp"
        ".mm"
    end
  end

  def stdlib_flag
    if is_cxx?
      is_darwin? ? '-stdlib=libc++' : '-stdlib=libstdc++'
    else
      ''
    end
  end

  def exception_flag
    if is_cxx?
      if @enable_exns
        "-fexceptions" + (is_objc? ? " -fobj-exceptions" : "")
      else
        "-fno-exceptions" + (is_objc? ? " -fno-objc-exceptions" : "")
      end
    else
      ''
    end
  end

  def rtti_flag
    if is_cxx?
      @enable_rtti ? '-frtti' : '-fno-rtti'
    else
      ''
    end
  end

  def flags
    %W[
      -x#{@lang}
      -march=#{@arch}
      #{@force_bits.nil? ? '' : "-m#{@force_bits}"}
      -S
      #{@emit_llvm ? '-emit-llvm': ''}
      #{@verbose_asm ? '-Xclang -masm-verbose' : ''}

      -std=#{@std}
      #{stdlib_flag}
      -O#{@opt_level.strip}

      #{exception_flag}

      #{rtti_flag}

      #{@accurate_fp ? '' : '-ffast-math'}

      #{@warnings.map{|s| to_warning s}.join ' '}
      #{@includes.map{|s| to_include s}.join ' '}

      #{@defines.reject(&:empty?).map{|d|"-D#{d.strip}"}.join ' '}
      #{@undefs.reject(&:empty?).map{|u|"-U#{d.strip}"}.join ' '}

      #{@debug ? '-g' : ''}
      #{@xflags.join ' '}
    ].reject(&:empty?)
  end

  def flag_str
    flags.join ' '
  end

  def to_warning(s)
    s.strip.sub /^(?:-?W)?/, "-W"
  end

  def to_include(s)
    s.strip.sub /^(?:-I)?/, "-I"
  end

  def flags_summary
    flags.reject{|f| /^-[WI]/ =~ f}.join ' '
  end

  def should_demangle
    @demangle and is_cxx?()
  end

  def compiler_cmd path, summarize
    command = "clang " + (summarize ? flags_summary : "#{flag_str} #{path} -o '-'")
    command += " | clang -cc1as -show-encoding" if @show_encoding
    command += " | c++filt" if should_demangle
  end

  def compiled_with comment_str
    cmd = "clang #{flags_summary} "
    cmd += " | clang -cc1as -show-encoding" if @show_encoding
    cmd += " | c++filt" if should_demangle
    "#{comment_str} Compiled with `#{cmd}`\n"
  end

  def invoke_compiler path
    # this is getting pretty hacky
    out = IO.popen("clang #{flag_str} #{path} -o '-'") do |pipe|
      pipe.read
    end

    unless $?.exitstatus == 0
      return [false]
    end

    if @show_encoding
      out = IO.popen('clang -cc1as -show-encoding', 'r+') do |pipe|
        pipe.write out
        pipe.close_write
        pipe.read
      end
      unless $?.exitstatus == 0
        return [false]
      end
    end

    if should_demangle
      out = IO.popen('c++filt', 'r+') do |pipe|
        pipe.write out
        pipe.close_write
        pipe.read
      end
      unless $?.exitstatus == 0
        return [false]
      end
    end
    [true, out]
  end

  def template
    if @custom_template
      @custom_template
    elsif is_cxx?
      CXX_TEMPLATE
    else
      C_TEMPLATE
    end
  end

  def run
    parse_settings!

    compiled = nil
    file = nil

    if @input.nil?
      templ = template
    else
      templ = IO.read @input
    end

    file = Tempfile.new(['asmcc', file_extension])

    path = file.path

    file.print template
    file.close()

    compiled = nil
    tried_once = false

    while true
      edit_file path if @input.nil? or tried_once
      tried_once = true
      result = invoke_compiler path
      if result[0]
        compiled = result[1]
        break
      elsif not try_again? "Compilation failed, try again?", true
        exit(1)
      end
    end

    if @edit_asm or not @output.nil?
      out_path = @output.nil? ? path : @output
      File.open(out_path, 'w') { |f| output f, (IO.read path), compiled }
      edit_file out_path if @edit_asm
    else
      output $stdout, (IO.read path), compiled
    end
  end

  def output f, source, compiled
    if @combined_output
      f.puts source
      f.puts "\n/******* Generated code *********/"
      f.puts compiled_with "/*"
    else
      f.puts compiled_with @emit_llvm ? ';' : '#'
    end
    f.puts compiled.each_line.to_a.map{|line| "#{line.gsub(/([^\t]*)(\t)/) { $1 + " " * (8 - $1.length % 8) }}"}.join
    f.puts "\n*/" if @combined_output
  end

end
