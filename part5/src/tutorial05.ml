open Llvm

exception Error of string

(* module L = Llvm *)

type id = int

module String = struct
  type t = string
  let compare = Pervasives.compare
end

module StringMap = Map.Make(String)

(* type ptype =  *)

type aexpr =
  | Anum of int
  | Avar of string
  | Aadd of aexpr * aexpr
  | Asub of aexpr * aexpr
  | Amul of aexpr * aexpr

type bexpr =
  | Btrue
  | Bfalse
  | Band of bexpr * bexpr
  | Bnot of bexpr
  | Beq of aexpr * aexpr
  | Ble of aexpr * aexpr

type com =
  | Cskip
  | Cassign of string * aexpr 
  (* | Clet of string * TypeKind.t * aexpr *)
  | Clet of string * aexpr
  | Cseq of com * com
  | Cif of bexpr * com * com
  | Cwhile of bexpr * com

open StringMap
let _ =

  let named_values:(string, llvalue) Hashtbl.t = Hashtbl.create 10 in

  let m = add "a" "plepps" empty in
  let f = find "a" m in
  Printf.printf "Plepps : %s\n" f ;

  let e = Aadd (Anum 1, Anum 2) in
  let e = Aadd (e, e) in


  let l = Clet ("a", Anum 1) in (* later we will have type *)

  (* let e = aexpr Aadd (aexpr (Anum 1) (aexpr (Anum 2)) in *)


  let llctx = global_context () in
  let llm = create_module llctx "mymodule" in

  let i8_t = i8_type llctx in
  let i32_t = i32_type llctx in
  let int_exp i = const_int i32_t i in

  let c = Cassign ("a", e) in

  (* Create an alloca instruction in the entry block of the function. 
     This is used for mutable variables etc. *)
  let create_entry_block_alloca f s =
    (* let eb = entry_block f in
       let ib = instr_begin eb in
       let b = builder_at ib in
    *)
    let b = builder_at llctx in 
    (* (entry_block f, ) *)
    ()

  (* let builder = builder_at (instr_begin (entry_block f)) in
     build_alloca i32_t s builder *)
  in

  let rec aexpr_to_llvm builder = function 
    | Anum v -> int_exp v
    | Avar s -> 
      let v = try Hashtbl.find named_values s with
        | Not_found -> raise (Error "unknown variable name")
      in
      (* Load the value. *)
      build_load v s builder
    | Aadd (ae_l, ae_r) -> 
      let l = aexpr_to_llvm builder ae_l in
      let r = aexpr_to_llvm builder ae_r in
      build_add l r "add" builder   
    | _ -> int_exp 0   
  in

  let rec com_to_llvm builder = function
    (* | Clet (s, e) ->
       let let_alloc = create_entry_block_alloca "main" s in 
       let let_exp = aexpr_to_llvm builder e in

       build_store let_alloc let_exp builder  *)
    | _ -> int_exp 0 

  in

  let fty = function_type i32_t [| |] in

  let f = define_function "main" fty llm in
  let llbuilder = builder_at_end llctx (entry_block f) in


  let printf_ty = var_arg_function_type i32_t [| pointer_type i8_t |] in
  let printf = declare_function "printf" printf_ty llm in
  (* add_function_attr printf Attribute.Nounwind ; *)
  (* add_param_attr (param printf 0) Attribute.Nocapture ; *)

  let s = build_global_stringptr "Hello, world! %d\n" "" llbuilder in
  (* try commenting these two lines and compare the result *)
  (* let zero = const_int i32_t 0 in
     let s = build_in_bounds_gep s [| zero |] "" llbuilder in  *)

  (* let c = int_exp 17 in
     let exp = build_add c c "" llbuilder in *)

  (* let exp = aexpr_to_llvm llbuilder e in *)
  let exp = com_to_llvm llbuilder l 
  in
  (* array [| e1; e2; ...] *)
  let _ = build_call printf [|s; exp |] "not sure what this is for" llbuilder in

  let _ = build_ret (const_int i32_t 0) llbuilder in

  Llvm_analysis.assert_valid_module llm ;
  let _ =
    if Array.length Sys.argv > 1
    then Llvm_bitwriter.write_bitcode_file llm Sys.argv.(1) |> ignore
    else dump_module llm
  in
  ()
