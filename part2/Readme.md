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

In this case, `hello.c` was compiled without optimizations.

---

## Exercise 1

Make a branch `t2_ex1` where you work on exercise 1.

Generate `hello.ll`:

``` shell
> clang -S -emit-llvm hello.c
> make run > out
```

Now edit the `out` file, and carefully match the `out` file to the LLVM-IR (`hello.ll`) and comment (by inspecting the OCaml code) on how the `out` file was generated. Be prepared to show that you fully understood the "analysis" made by the OCaml program.

Commit your edited `out` file.

## Exercise 2

Make a branch `t2_ex2` where you work on exercise 2.

Now use your `hello.c` with the `add2` function.

``` shell
> cp ../part1/hello.c
> clang -S -emit-llvm hello.c
> make run > out2
```

Now edit the `out2` file, and carefully match the `out2` file to the LLVM-IR (`hello.ll`) and comment (by inspecting the OCaml code) on how the `out2` file was generated. Be prepared to show that you fully understood the "analysis" made by the OCaml program.

Commit your edited `out2` file.

## Exercise 3

Make a branch `t2_ex3` where you work on exercise 3.

Now its finally time for some coding. Change the program (`src/tutorial02.ml`) to that it prints the basic blocks for each function (intstead of printing all basic blocks at top level). 

Make sure your program compiles without errors/warnings and that it produces the expected output.

---

## Learning outcomes

1. Understanding LLVM objects, values, functions, basic blocs and instructions.

2. Understanding how to inspect/traverse the LLVM objects.

3. Writing OCaml to inspect specific LLVM objects.
