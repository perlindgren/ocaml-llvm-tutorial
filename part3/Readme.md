# Tutorial 3

This part explains how to create LLVM IR, and write a simple application from scratch, and see how to build and run it.

## Modules

As in the previous tutorial, we need to create a context and a module:

``` OCaml
let llctx = global_context () in
let llm = create_module llctx "mymodule" in
``` 

## Functions

There are two actions that can be done on functions:

- declare_function to give only a declaration of the prototype,

- define_function to give both the declaration and the implementation.

In both cases, we need to give the signature (return type, number and type of arguments) of the function.

This is pretty similar to C. We’ll use this to declare the function int `main(void)`.

The `int` type is a bit problematic in LLVM (and in C, but for other reasons): integer types must have a known size in LLVM. While this does not change the architecture-independent property of LLVM IR, it can sometimes create problems when writing code that has to run on 32 and 64 bits platforms, while trying to use registers for performance reasons.

Here, we will declare a 32 bits integer type (mostly to simplify later commands):

``` OCaml
let i32_t = i32_type llctx in
```

and use it to declare the prototype of the function

``` OCaml
let fty = function_type i32_t [| |] in
```

The `i32_t` here is the return type, and the array is the type of arguments (empty means void, not unknown or variable).

The signature type can then be used to create the function, in the current module:

``` OCaml
let f = define_function "main" fty llm in
```

The returned object `f` is a `llvalue`, so functions from the previous tutorial to print the type or the content of the value can be used.

The function is currently empty: it contains a single basic block (the entry block) with no instructions. We now need to add instructions.

## Instructions

To add basic blocks and instructions, we first need to create a `llbuilder` object. The instruction builder is used to insert instruction at its position. We create a builder, positioned at the end of the entry block of the function `f`:

``` OCaml
let llbuilder = builder_at_end llctx (entry_block f) in
```

Now that we have the context, the function and the builder objects, we can insert instructions. For this very simple example, we will only simulate a `return 0`:

``` OCaml
let _ = build_ret (const_int i32_t 0) llbuilder in
```

To write the module, it is possible either to simple dump it (and save `stderr`), or to use the `Llvm_bitwriter` modules.

We this we intend to build something along the lines of:

``` LLVM
; ModuleID = 'mymodule'

define i32 @main() {
entry:
  ret i32 0
}
```

---

## Building the module

The following is not related to the OCaml bindings, but to cover the topic, I will explain how to build the resulting module.

First, if the output was saved as text (LLVM IR) in a file hello.ll, it needs to be compiled to LLVM bitcode:

``` shell
> llvm-as hello.ll
```

If the LLVM module was saved using `Llvm_bitwriter.write_bitcode_file`, then it is already in bitcode format.

Then, the `llc` compiler is used to produce an assembly file from the bitcode:

``` shell
> llc hello.bc
```

`llc` has many options, some of the most interesting are:

- -O0, -O1, -O2 ...: the “classical” optimization options

-  -march=<arch>: specify the target architecture (x86, x86-64, arm, etc.). The list of architectures can be found using `llc 
--version`.

The options are described in the `llc --help` command. However, this is not an exhaustive list, and there are many undocumented options. A more complete list can be obtained using the (undocumented) `llc --help-hidden` command.

Note: the `--help` arguments gives 126 options here, while the `--help-hidden` is some 2k lines long (a horrible read).

After that, the assembly file is compiled as usual into an object file, then an executable.

``` shell
> clang -c hello.s
> clang -o hello hello.o
```

The executable from this example works as expected (it does nothing):

``` shell
> ./hello
> echo $?
0
```

(Under `fish` shell, use `echo $status` to print the returned status of the last invoked program.)

## Exercise 1

Make a branch `t3_ex1` where you work on exercise 1.

Change the program (`src/tutorial03.ml`) to return a 1 (instead of 0).

``` shell
> make clean
> make run
```

Now inspect the status:

``` shell
> echo $?
```

You got a 2, right? 

Now try:

``` shell
> ./hello
> echo $?
```

You got a 1, right? (If not your program did not compil correctly).

Try figuring out why the status was 2 when running `make run` (look at the Makefile, what did it actually do?).

## Exercise 2
