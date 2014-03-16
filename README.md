# asmcc
A small tool to view the assembly or LLVM IR produced by clang. Essentially a command-line version of the now-defunct [http://llvm.org/demo/](llvm online demo page).

The basic idea is that you run the `asmcc` command and it opens up a text editor window for you. You enter the desired code into said editor, and it compiles the code to assembly and writes the result to stdout. If there's a compilation error, it will ask you if you want to reopen the code in an editor to try again. You can do this as many times as you want.

Depending on the options you invoke it with, you can run it on a file (bypassing the text editor), write the result to a file, emit llvm IR, control the language used, etc. See Usage for full list of options.

I'm not a ruby programmer by any stretch of the imagination, and it's grown organically over the past year or so. As a result, the script itself is fairly messy, but it works well enough.

## Usage

### Dependencies
You need to have clang installed and on your path to use it.  You also need a ruby installation, version 2.0 or higher ideally, but it will probably work with a lower version (let me know if it does not).  It has no dependencies on any other programs/gems/libraries.

### Installing
Install by downloading the `asmcc` script and putting it in your path somewhere. Probably the best way to do this is to clone the repo and symlink it there.

For example, if you have a `~/bin` folder on your path, you might install it like this:

```
$ git clone https://github.com/thomcc/asmcc.git
$ ln -s asmcc/asmcc ~/bin/asmcc
```

You also should set either the `EDITOR` or `VISUAL` environment variables to your preferred text editor. `asmcc` expects that calling one of these commands will block until the file closes.

### Options
Note that the `=` between the long version is optional.

- `-g`, `--debug-info`: Tell the compiler to generate debug info.
- `-O LEVEL`, `--opt-level=LEVEL`: Set optimization level, which should be `0`, `1`, `2`, `3`, or `s`. Defaults to `3`.
- `-l LANG`, `--lang=LANG`: Compile a `LANG` file, where `LANG` is one of `c++`, `c`, `objective-c`, `objective-c++`. Defaults to `c++`.
- `-s STD`, `--std=STD`. Passes `-std=STD` to the compiler. If the given standard doesn't make sense for the chosen language, it uses the default. Defaults to `c++1y` if the language is C++ or Objective C++, and `c11` if the language is C or Objective C.
- `-L`, `--emit-llvm`: Emit LLVM IR instead of assembly. If this is selected, `--show-encoding` is turned off.
- `-F`, `--[no-]fast-math`: Pass `-ffast-math` to the compiler. Defaults to off.
- `-a ARCH` `--arch=ARCH`: Pass `-march=ARCH` to the compiler. Defaults to `native`.
- `--m32`: Generate 32 bit code (pass `-m32` to the compiler).
- `--m64`: Generate 64 bit code (pass `-m64` to the compiler).
- `-X list,of,flags`, `--Xcc=list,of,flags`: Escape hatch which allows you to pass whatever options you want to the compiler. These are passed at the end, so they'll override earlier ones if you want.
- `-e` `--[no-]exceptions`: Turn on c++ and objective-c exceptions.  These are off by default, because they bloat the generated and causes it to be more difficult to read.
- `-r` `--[no-]rtti`: Turn on c++ runtime type information. This is off by default for the same reason as exceptions.
- `-E`, `--edit-result`: Open asmcc's output in a text editor. See also `-C`.
- `-o FILE`, `--out FILE`: Write asmcc's output to `FILE`. If this is used with `-E`, it will open `FILE` in the text editor. See also `-C`.
- `-C`, `--combined-output`: Output both the source fed to the compiler and the generated assembly (as well as the flags passed to the compiler, as always). Useful if you intend to show your output to other people. (Places the generated code in the comments of a copy of the input file)
- `-D L,I,S,T`, `--define L,I,S,T`: passes `-DL -DI -DS -DT` to the compiler.
- `-U L,I,S,T`, `--undef L,I,S,T`: passes `-UL -UI -US -UT` to the compiler. These override symbols defined with `-D`, as they are passed to the compiler after.
- `-W w0,w1,w2`, `--warn=list,of,warnings`: Passes warnings to the compiler. By default `-Wall` and `-Wextra` are passed in. (NB: This will normalize the names of what you pass in: `--warn=all,extra`, `--warn=Wall,Wextra`, and `--warn=-Wall,-Wextra` will all mean the same thing).
- `-I dir0,dir1,dir2`, `--include=list,of,directories`: Add directories to the compilers list of include search paths, e.g. passes `-Ilist`, `-Iof`, `-Idirectories` to the compiler. By default it passes `-I. -I./include -I/usr/local/include` to the compiler.
- `-S`, `--show-encoding`: Show the assembly's binary encoding in comments. Only valid if `--emit-llvm` isn't selected.
- `--no-verbose-asm`: Disable verbose assembly output (which is enabled by default). Irrelevant if used with `-E`.
- `-i FILE`, `--input=FILE`: Read file as input instead of opening it in an editor. If you choose this option and you get a compilation error, it copies the contents of the file to a temp file, which it opens in an editor for you (thus sparing you from needing to change your file).
- `-T FILE`, `--template=FILE`: Use `FILE` as a template. Like `-i FILE` but lets you modify the file in a text editor before trying to compile.
- `-v`, `--verbose`: Pass `-v` to the compiler.
- `-h`, `--help`: Print out a help summary and exit.
- `-d`, `--demangle`: Demangle c++ identifiers (runs code through `c++filt`).

## Caveats
- C++ is the default language. The default standard is `c++1y`.
- Exceptions are off by default.
- RTTI is off by default.
- Only tested on Mac (but should probably work on other unices. Let me know if you have a problem).

## TODO (someday)
- Allow user to specify the default options and templates using a config file.
- Support gcc.
- Turn into a gem for easier distribution.
- Allow user to change the compiler/asmcc options after compilation fails.

## License
Public domain, as described here: [http://creativecommons.org/publicdomain/zero/1.0/](CC0). I don't care what you do with it.
