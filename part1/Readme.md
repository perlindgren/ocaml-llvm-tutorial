# Tutorial 1

In this tutorial we will learn about the `clang` and `opt` interfaces to the LLVM compiler infrastructure.

---

## Install

* llvm
* ocaml
* vscode
* ocaml plugin
* indent
* merlin

---

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

---

## `clang`

`clang` is a C frontend, which invokes the compilation process and by default renders a binary executable.

``` shell
> clang hello.c
> ./a.out
```

You may invoke `clang` with flags to gain fine grained control, e.g., shows the generated x86 assembly program:

``` shell
> clang -S hello.c
> more hello.s
```

We may also want to inspect the LLVM-IR (internal LLVM representation) of a program. LLVM uses two formats `.bc` (binary bitcode) and `.ll` (textual). To generate a `.bc`:

``` shell
> clang -c -emit-llvm hello.c
```

And to generate a `.ll`

``` shell
> clang -S -emit-llvm hello.c
```

You may use `clang` to compile an LLVM-IR to an executable.

``` shell
> clang hello.ll
> ./a.out
```

and/or

``` shell
> clang hello.bc
> ./a.out
```

---

## Makefiles

Makefiles (and the `make` tool), provides a powerful means to autamate invakations of other command line utilities and tools. The above compilations are replicated in the Makefile.

``` shell
> make a.out
> make hello.bc
> make hello.s
> make hello.ll
```

---

## The LLVM tool-chain

## `opt`

`opt` is a utility to directly access the LLVM optimizer/analyzer, and operates directly on the LLVM representation (taking either `.ll` or `.bc` files).

An example, first remove all output files:

``` shell
> make clean
```

Compile into bitcode:

> make hello.bc

Read the bitcode and generate a textual representation.

``` shell
> opt -S hello.bc > hello.ll
```

## `llvm-as`

`llvm-as` is used to compile LLVM-IR (human readable `.ll`) to bitcode.

## `llc`

`llc` compiles the LLVM-IR to assembly for the given target.

## `as`

`as` compliles the assembly code to object files (`.o`).

## `lld`

`lld` is a (LLVM) utility to link object files, e.g., producing an exectuable  or a library. Executables follow the `.elf` format by default under Linux. There are plenty of tools (e.g., `llvm-objdump`) to inspect the generated binaries (executable `elf` files).

The above tools (except `llvm-objdump`) are all wrapped by `clang` (under user control by various flags). As an end user, we typically do not need to care, but we might need them later.

---

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

``` shell
> make run
```

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

``` shell
> make clean
```

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

---

## Exercise 1

Make a branch `t1_ex1` where you work on exercise 1.

Implement the `add2` function code below that returns the sum of two integer arguments.

File `hello.c`:

``` C
#include <stdio.h>

// your function here

{
	int res = add2(2, 3);
	printf("hello world, add(2, 3) = %d\n", res);

	return 0;
}
```

Compile and run your code. Make sure it compiles without errors, and that it produces the expected result.

Generate the file `hello.ll`.

Identify in the generated file:
0. the `add2` function declaration (and its type).
1. the parameters in `add2`, and how parameters are declared, passed and stored.
2. the actual addition.
3. the return value.

4. in `main`, the local variable `res` declaration.
5. the call to `add2`
6. storing the result in `res`.
7. passing `res` as a parameter for `printf`

Commit your changed `hello.c` and generated `hello.ll` (with your comments included). Be prepared to show your findings in the next session.

As you see, LLVM-IR is very verbose, partly due to the Static Single Assignment (SSA) form, (allowing each "variable" to be assigned only once). Notice, all these intermediate assignments are not necessary, and a clever compiler (like LLVM) can optimize away most of them as we will see in the next exercise.

---

## Exercise 2

Make a branch `t1_ex2` where you work on exercise 2.
Make sure you have the `hello.bc` that you created in exercise 1.

You can pass optimization options to `clang`. Run:

``` shell
> clang -O3 hello.bc
> ./a.out
```

Well, presumably it executed faster, but this program is really simple, so we can't tell by the naked eye.

Let's look at the LLVM-IR instead. You may change the makefile or just run:

``` shell
> clang -S -O3 -emit-llvm hello.c
> more hello.ll
```

Now repeat the inspection on the new `hello.ll`:

Identify in the generated file:
0. The `add2` function declaration (and its type).
1. The parameters in `add2`, and how parameters are declared, passed and stored.
2. The actual addition.
3. The return value.

4. In `main`, the local variable `res` declaration.
5. The call to `add2`
6. Storing the result in `res`.
7. Passing `res` as a parameter for `printf`

You should find that LLVM was able to a VERY good job!!!!

Here are some additional questions!

If trying to debug the code using `gdb`:
8. Would you be able to spot the call to `add2`?
9. Would you be able to spot the vale of `res`?
10. ... what impact has optimization to debugging?
11. Is `add2` actually needed at all in the executable?
12. What do you think the linker should/will do with `add2`? (If you are really curious you may look into the generated `elf` using `llvm-objdump -d  a.out`. Notice, your code is linked to a C run-time/startup code, so it is not only your code that is visible in the `.elf`.)

Commit your generated `hello.ll` (with your comments included). Be prepared to show your findings in the next session.

---

## Learning outcomes

1. Installing and managing your tool-chain.

2. Getting a first experience with `clang`, `opt`, and the use of `make` and Makefiles.

3. Getting basic knowledge on accessing LLVM from OCaml code.

4. First experience on inspect generated LLVM-IR, both before and after optimization.

5. Gaining a general feeling of the compilation process.

If you feel lost at some point, you can always go back to this tutorial to ensure you got the basics of the compilation process pinned down.

In the next tutorials we will focus on the LLVM-IR representation and how we can inspect, manipulate and generate our own LLVM-IR programs.