# Tutorial 4

To be able to generate realistic code, we now need to add a few more things. This part explains how to create bitcode with a correctly specified target triple, how to verify bitcode, and write a hello world application.

## Target Triple and Data Layout

While LLVM IR is (or should be) target independent, there are a few things that are not. For example, the support for some instructions, the padding and alignment inside structures, the endianness, the size of pointers, etc. All these things are specified in two attributes of modules: the target triple, and the data layout.

In the current (3.5) version of LLVM, these two attributes are optional. However, they could become mandatory in the future, so it is best specifying them.

Note: in my personal opinion, specifying that inside the module is clearly redundant with the -march= option of llc. Most of this could have been handled by compiler flags, instead of creating situations where one can give a target triple in the module, and use a different target on the command-line. Let’s suppose that there are “historic” reasons.

The target triple is a string that describes the target host. It is usually a simple string (i686), or a minus-separated (-) string to give the full architecture (x86_64-apple-macosx10.7.0). It is the same as the argument of the `-march=<target>` option of clang or gcc, so this one should be easy to guess.

The data layout is a compact string, for example e-m:e-p:32:32-f64:32:64-f80:32-n8:16:32-S128, that describes the specifications of the data layout in memory. All fields are minus-separated (-).

In the previous example string, this can be decoded as:

    e: little-endian
    m:e: ELF mangling of names is enabled
    p:32:32: size of a pointer is 32 bits, preferred alignment is 32 bits
    f64:32:64: for floating point size 64 bits, abi is 32 bits and alignment is 64 bits
    f80:32: for floating point size 80 bits, abi is 32 bits
    n8:16:32: set of native integer widths of target CPU
    S128: natural alignment of stack is 128 bits

The string format is detailed in the LLVM datalayout section of the LLVM Language Reference.

Specifying the target triple and data layout can be tedious and error-prone. Instead of building the string manually, we’ll use the LLVM functions to find the target, the machine and the data layout from the target triple:

``` OCaml
let lltarget  = Llvm_target.Target.by_triple triple in
let llmachine = Llvm_target.TargetMachine.create ~triple:triple lltarget in
let lldly     = Llvm_target.TargetMachine.data_layout llmachine in
```

Here, triple is the name of the target architecture, for example x86 of x86_64. Then, we can set this information into the module:

set_target_triple (Llvm_target.TargetMachine.triple llmachine) llm ;
set_data_layout (Llvm_target.DataLayout.as_string lldly) llm ;

If you want to print the values (for debugging purposes):

Printf.printf "lltarget: %s\n" (Llvm_target.Target.name lltarget);
Printf.printf "llmachine: %s\n" (Llvm_target.TargetMachine.triple llmachine);
Printf.printf "lldly: %s\n" (Llvm_target.DataLayout.as_string lldly) ;

We create a function to easily add the data layout and target triple, and will use that for every tutorial from now.
Module verification

To verify a module, LLVM provides a very help function that will run many tests, and print the validation report to stderr, and abort if the module is invalid. To call it, just add the llvm.analysis pkg to the Makefile, and call:

Llvm_analysis.assert_valid_module llm ;

Trust me, you really want to use this. This will save you a lot of trouble. In fact, if you produce an invalid LLVM module, all tools will probably just segfault, including OCaml bindings functions. Unless you compiled LLVM in debug mode, the segfaults give no clue of what the problem is. So if you don’t want to become crazy, always verify the generated LLVM modules.
Calling functions

As usual in C, to call a function you first need to declare its prototype. In the previous tutorial, we’ve seen how to declare the prototype of a simple (fixed number of arguments) function, for example, to declare the equivalent to the C function int32_t test(void):

let i32_t = i32_type llctx in
let fty = function_type i32_t [| |] in
let f = define_function "test" fty llm in

Our current example is to create the call printf("Hello, world!\n"). However, printf belongs to another kind of functions, accepting a variable number of arguments.

The first argument of printf is a (constant) string. There is no such type in LLVM, the equivalent being a pointer to an integer of size 8 (int8_t *).

We define the equivalent prototype of int32_t printf(int8_t*, ...):

let i8_t = i8_type llctx in
let i32_t = i32_type llctx in
let printf_ty = var_arg_function_type i32_t [| pointer_type i8_t |] in
let printf = declare_function "printf" printf_ty llm in

This gives a perfectly usable definition of printf. While this works, we also should add some function attributes. These attributes are important, because they help the LLVM compiler for optimizations and verifications, and in some cases they are even required to not generate wrong code. Attributes are defined in the Attribute module of llvm.mli.

One attribute to add to the printf function is nounwind, meaning that it will not raise any exception:

add_function_attr printf Attribute.Nounwind ;

The other kind of attributes that can be set is on parameters. Here, the nocapture attribute is added on the first parameter, to declare that printf does not make any copy of it, that survives the callee of printf.

add_param_attr (param printf 0) Attribute.Nocapture ;

Remember that attributes are declarative, they are not checked. If you declare wrong attributes, the compiler can generate wrong code, that will probably be invalid or segfault at runtime.

Now that the prototype is correct, we only need to call printf. The last thing to do is to create the constant string.

In LLVM, a constant string is a global constant, defined as a NULL-terminated array of characters. It needs to be declared as a global value:

let s = build_global_stringptr "Hello, world!\n" "" llbuilder in

Remember that this only works for constant strings.

Last thing before using it as argument to printf: the type of the constant is not the same. The constant has type [15 x i8], which means an array of 15 elements of integers of size 8, while the expected type is i8*.

It’s not the same (even if some C programmers thinks so), so it must be converted to get the address of the first element of the array. This is done using the getelementptr function (often called GEP):

let zero = const_int i32_t 0 in
let s = build_in_bounds_gep s [| zero |] "" llbuilder in

Note that, this function is so confusing that it has its own FAQ in the documentation!

Finally, call the printf function, and return:

``` OCaml
let _ = build_call printf [| s |] "" llbuilder in
let _ = build_ret (const_int i32_t 0) llbuilder in
```

## Test

The Previous tutorial already covered the compilation of the module, so I’ll just show the instructions:

``` shell
> LD_LIBRARY_PATH=/usr/lib/ocaml/llvm-3.5/ ./build/tutorial04/src/tutorial04.byte 2>hello.bc
> llc-3.5 hello.bc
> clang -o hello hello.s
```

and the execution:

``` shell
> ./hello
Hello, world!
```

Additional notes

In fact, the conversion is optional (at least in OCaml bindings for LLVM 3.5). If you call printf without the GEP, dumping the module will show you that LLVM has inserted an inline GEP:

``` LLVM-IR
%0 = call i32 (i8*, ...)* @printf(i8* getelementptr inbounds ([15 x i8]* @0, i32 0, i32 0))
```
