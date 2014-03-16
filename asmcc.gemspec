Gem::Specification.new do |spec|
  spec.name = 'asmcc'
  spec.version = '0.4.0'
  spec.summary = 'A script which painlessly compiles C/C++ to assembly.'
  spec.executables << 'asmcc'
  spec.bindir = 'bin'
  spec.description = <<-EOS.gsub(/^ {6}/, '')
      AsmCC is a command line tool to view the assembly or LLVM IR produced by
      clang for a given file.  It's essentially a command-line version of the
      (now disabled) llvm online demo page.
    EOS
  spec.authors = ['Thom Chiovoloni']
  spec.email = 'chiovolonit@gmail.com'
  spec.files = ['lib/asmcc.rb']
  spec.require_paths = ['lib']

  spec.homepage = 'https://github.com/thomcc/asmcc'
  spec.license = 'CC0'
end
