# Tutorial 1

In this tutorial we will learn about the `clang` and `opt` interfaces to the LLVM compiler infrastructure.

## Install

* llvm
* ocaml
* vscode
* ocaml plugin
* indent
* merlin

## Merlin

Merlin will help you with looking up symbols, types etc. To this end it needs to know some detatails on your project.

``` Merlin
PRJ tutorial01
S src
FLG -w -30

PKG ounit

PKG llvm

PKG ctypes

PKG ocamlbuild

B build/src
```

## `clang`

`clang` is a C frontend, which invokes the compilation process and by default renders a binary executable.

> clang hello.c
> ./a.out

You may invoke `clang` with flags to gain fine grained control, e.g., shows the generated x86 assembly program:

> clang -S hello.c
> more hello.s

We may also want to inspect the LLVM-IR (internal LLVM representation) of a program. LLVM uses two formats `.bc` (binary bitcode) and `.ll` (textual). To generate a `.bc`:

> clang -c -emit-llvm hello.c

And to generate a `.ll`

> clang -S -emit-llvm hello.c

You may use `clang` to compile an LLVM-IR to an executable.

> clang hello.ll

and/or

> clang hello.bc

## Makefiles

Makefiles (and the `make` tool), provides a powerful means to autamate invakations of other command line utilities and tools. The above compilations are replicated in the Makefile.

> make a.out
> make hello.bc
> make hello.s
> make hello.ll

## `opt`

`opt` is a utility to directly access the LLVM optimizer/analyzer, and operates directly on the LLVM representation (taking either `.ll` or `.bc` files).

An example, first remove all output files:

> make clean

Compile into bitcode:

> make hello.bc

Read the bitcode and generate a textual representation.

> opt -S hello.bc > hello.ll

## Accessing LLVM as a library

LLMV is providing a modular compiler infrastructure, accessible as a library with interfaces/bindings to numerous languages including OCaml.

The file `src/tutorial01.ml` reads and parses a bitcode file and dumps the parsed file.

``` ocaml
let _ =
  let llctx = Llvm.global_context () in
  let llmem = Llvm.MemoryBuffer.of_file Sys.argv.(1) in
  let llm = Llvm_bitreader.parse_bitcode llctx llmem in
  Llvm.dump_module llm ;
  ()
```

For in-depth information about the LLVM API and ocaml bindings see https://llvm.moe/ocaml/.

> make run

This will compile the `hello.c` into a `.bc` LLVM bitcode file (binary LLVM representation of the program). It will also build and run the `src/tutorial01.ml` OCaml program, that reads the bitcode file (using the `llvm-ocmal` bindings) and prints the resulting representation in text format.

## Project layout

``` shell
part1/
├── build
├── Makefile
└── src
    └── tutorial01.ml
```

Let's break down the source file:

``` OCaml
  let llctx = Llvm.global_context () in
```

LLVM requires a context (LLVMContext in the C++ API), to transparently own and manage all data. Here, there is no need to create a context, so we get the global one.

``` OCaml
  let llmem = Llvm.MemoryBuffer.of_file Sys.argv.(1) in
```

This line takes the first command-line argument of the application, and uses the LLVM-OCaml bindings API to read it into memory (as a `llmemorybuffer` opaque object). Input format should be LLVM bitcode, usually a file with the `.bc` extension.

``` OCaml
  let llm = Llvm_bitreader.parse_bitcode llctx llmem in
```

After reading the LLVM bitcode file, the `llmemorybuffer` can now be parsed to create a LLVM module, in OCaml a `llmodule`. In LLVM, a module is a single unit of code to process. It contains things like functions, structures definitions and global variables, and usually matches the content of a single file to be compiled.

``` OCaml
  Llvm.dump_module llm ;
```

The dump_module function prints the contents of the module to `stderr`, in the textual LLVM IR form (you may also dump to a file or string, see detailed API). Its main purpose is debugging, and fits well the goal of this first tutorial.

## Makefile

The makefile also defines:

> make clean

To clean the build.

> make hello.bc

To generate the bitcode.

The complete `Makefile` is depicted below.

`TARGET` set to `native` for binary exuctable, or `byte` for `ocamlrun` executable.

``` Make
SRC_DIR:=src

TOOLS:=tutorial01

TARGET:=native
#TARGET:=byte

LLVM_VERSION := 8.0
CLANG := clang

OCAMLBUILDFLAGS:=-classic-display -j 0 -cflags -w,@a-4

export OCAMLPATH=/usr/lib/ocaml/llvm

tutorial01_OCAMLBUILDFLAGS:=-use-ocamlfind -pkgs llvm,llvm.bitreader -lflags -ccopt,-L/usr/lib/llvm-$(LLVM_VERSION)/lib

################
OCAMLBUILD:=ocamlbuild

CLEAN_RULES:=$(patsubst %,%-clean,$(TOOLS))

.PHONY: $(TOOLS) clean $(CLEAN_RULES) default run

default: $(TOOLS)

$(TOOLS):
	$(OCAMLBUILD) $(OCAMLBUILDFLAGS) $($@_OCAMLBUILDFLAGS) $($@_OCAMLBUILDFLAGS_$(TARGET)) -I $(SRC_DIR) -build-dir build/$@ $@.$(TARGET)

run: $(TOOLS) hello.bc
	./build/tutorial01/src/tutorial01.$(TARGET) hello.bc

 
clean: $(CLEAN_RULES)
	-rm -f a.out hello.bc hello.s hello.ll

$(CLEAN_RULES):
	$(OCAMLBUILD) $(OCAMLBUILDFLAGS) -I $(SRC_DIR) -build-dir build/$(patsubst %-clean,%,$@) -clean $(patsubst %-clean,%,$@).$(TARGET)

a.out: hello.c
	$(CLANG) hello.c

hello.bc: hello.c
	$(CLANG) -c -emit-llvm $<

hello.s: hello.c
	$(CLANG) -S $<

hello.ll: hello.c
	$(CLANG) -S -emit-llvm $<
```

## Exercise 1

Make a branch `ex1` where you work on exercise 1.

Implement the `add2` function code below that returns the sum of two integer arguments.

File `add2.c`:

``` C
#include <stdio.h>

// your function here
int add2(int a, int b)
{
	a + b
}


int main(void)
{
	int res = add(2, 3);
	printf("add(2, 3) %d\n", res);

	return 0;
}

```
