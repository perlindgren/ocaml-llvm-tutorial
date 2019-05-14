# Tutorial 2

In this tutorial we will learn more about the LLVM API, and howto access LLVM-IR from OCaml.

---

## LLVM objects

The top-level container is a module (`llmodule`). The module contains global variables, types and functions, which in turn contains basic blocks, and basic blocks contain instructions.

## Values

In the OCaml bindings, all objects (variables, functions, instructions) are instances of the opaque type `llvalue`.

A value has a type, a name, a definition, a list of users, and other things like attributes (for ex. visibility or linkage options) or aliases.

Each value has a type (`lltype`), which is a composite object to define the type of a value and its arguments. To match the real type, it needs to be converted to a `TypeKind.t`:

``` OCaml
let rec print_type llty =
  let ty = Llvm.classify_type llty in
  match ty with
  | Llvm.TypeKind.Function -> Printf.printf "  function\n"
  | Llvm.TypeKind.Pointer  -> Printf.printf "  pointer to" ; print_type (Llvm.element_type llty)
  | _                      -> Printf.printf "  other type\n"
```

We define a simple function to print a few informations about the input `llvalue` argument:

```
let print_val lv =
  Printf.printf "Value\n" ;
  Printf.printf "  name %s\n" (Llvm.value_name lv) ;
  let llty = Llvm.type_of lv in
  Printf.printf "  type %s\n" (Llvm.string_of_lltype llty) ;
  print_type llty ;
  ()
```

## Functions

The lookup_function can be used to get the `llvalue` associated to a function. It returns an `llvalue` option, so we must use match to check if the function exists:

``` OCaml
let opt_lv = Llvm.lookup_function "main" llm in
match opt_lv with
| Some lv -> print_val lv
| None    -> Printf.printf "'main' function not found\n"
```

If you don’t know the name of the functions, or simply wants to iterate on all functions, you can use the `iter_functions`, `fold_left_functions`, and similar functions:

``` OCaml
Llvm.iter_functions print_val llm ;
let count =
  Llvm.fold_left_functions
    (fun acc lv ->
      print_val lv ;
      acc + 1
    )
    0
    llm
in
Printf.printf "Functions count: %d\n" count ;
```

If you run the above code, please note that when iterating on functions, you always get a pointer to the function, not the function directly.

As usual in OCaml, it is better (for efficiency) to use the tail-recursive functions (for ex, fold_right_functions is not), especially when running on large LLVM modules. (Hopefully, the documentation clearly indicates if the iteration functions are tail-recursive or not.)

## Basic blocks and instructions

In LLVM, a function is made of basic blocks, which are lists of instructions. Basic blocks have zero or more instructions, but they must be ended by a terminator instruction, which indicates which blocks must be executed after the current one is ended. Basically, a terminator instruction is a flow change (ret, br, switch, indirectbr, invoke, resume), or unreachable.

A function has at least one basic block, the entry point.

The LLVM instructions are in static single assignment (SSA) form: a value is created by an instruction and can be assigned only once, and an instruction must only use values that are previously defined (in more precise words, the definition of a value must dominate all of its uses).

It is very important that the LLVM bitcode is well-formed: all constraints will be checked by the compiler, and the module will be rejected if not correct (the LLVM code uses internal assertions). As a consequence, you will get a segmentation fault if the compiler is compiled in release mode.

For example, to iterate on all instructions of all basic blocks of a function:

``` OCaml
let print_fun lv =
  Llvm.iter_blocks
    (fun llbb ->
      Printf.printf "  bb: %s\n" (Llvm.value_name (Llvm.value_of_block (llbb))) ;
      Llvm.iter_instrs
        (fun lli ->
          Printf.printf "    instr: %s\n" (Llvm.string_of_llvalue lli)
        )
        llbb
    )
    lv
```

Note that the order on the iteration of basic blocks is the iteration on the oriented graph (the control flow graph) of the function.

## Global variables

Access to global variables is done using similar functions: `iter_globals`, `fold_left_globals`, etc.

---

## Making a run for it!

``` shell
> make run > out
```

The file `out` is dispayed below:

``` shell
ocamlbuild -classic-display -j 0 -cflags -w,@a-4 -use-ocamlfind -pkgs llvm,llvm.bitreader -lflags -ccopt,-L/usr/lib/llvm-8.0/lib  -I src -build-dir build/tutorial02 tutorial02.native
# No parallelism done
./build/tutorial02/src/tutorial02.native hello.bc
*** lookup_function ***
Value
  name main
  type i32 ()*
  pointer to  function
*** iter_functions ***
Value
  name main
  type i32 ()*
  pointer to  function
Value
  name printf
  type i32 (i8*, ...)*
  pointer to  function
*** fold_left_functions ***
Value
  name main
  type i32 ()*
  pointer to  function
Value
  name printf
  type i32 (i8*, ...)*
  pointer to  function
Functions count: 2
*** basic blocks/instructions ***
  bb: 
    instr:   %1 = alloca i32, align 4
    instr:   store i32 0, i32* %1, align 4
    instr:   %2 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([14 x i8], [14 x i8]* @.str, i32 0, i32 0))
    instr:   ret i32 0
*** iter_globals ***
Value
  name .str
  type [14 x i8]*
  pointer to  array of  integer
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