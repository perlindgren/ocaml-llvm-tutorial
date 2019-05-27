open Llvm

module L = Llvm

type id = int

module Int = struct
  type t = int
  let compare = Pervasives.compare
end

module IntMap = Map.Make(Int)

type aexpr =
  | Anum of int
  | Avar of id
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
  | Cassign of id * aexpr 
  | Cseq of com * com
  | Cif of bexpr * com * com
  | Cwhile of bexpr * com

open IntMap

(* let op_exp (left_val: exp) (oper: A.oper) (right_val: exp) =
   let arith f tmp_name = f left_val right_val tmp_name builder in
   let compare f tmp_name =
    let test = L.build_icmp f left_val right_val tmp_name builder in
    L.build_zext test int_type "bool_tmp" builder
   in
   match oper with
   | A.PlusOp -> arith L.build_add "add_tmp"
   | A.MinusOp -> arith L.build_sub "minus_tmp"
   | A.TimesOp -> arith L.build_mul "mul_tmp"
   | A.DivideOp -> arith L.build_sdiv "div_tmp"
   | A.EqOp -> compare L.Icmp.Eq "eq_tmp"
   | A.NeqOp -> compare L.Icmp.Ne "neq_tmp"
   | A.LtOp -> compare L.Icmp.Slt "lt_tmp"
   | A.LeOp -> compare L.Icmp.Sle "le_tmp"
   | A.GtOp -> compare L.Icmp.Sgt "gt_tmp"
   | A.GeOp -> compare L.Icmp.Sge "ge_tmp" *)




let _ =


  let m = add 1 "plepps" empty in
  let f = find 1 m in
  Printf.printf "Plepps : %s\n" f ;

  let e = Aadd (Anum 1, Anum 2) in
  let e = Aadd (e, e) in

  let c = Cassign (1, e) in

  (* let e = aexpr Aadd (aexpr (Anum 1) (aexpr (Anum 2)) in *)


  let llctx = global_context () in
  let llm = create_module llctx "mymodule" in

  let i8_t = i8_type llctx in
  let i32_t = i32_type llctx in
  let int_exp i = const_int i32_t i in

  let rec aexpr_to_llvm builder = function 
    | Anum v -> int_exp v
    | Avar i -> int_exp i (* this is not correct *)
    | Aadd (ae_l, ae_r) -> 
      let l = aexpr_to_llvm builder ae_l in
      let r = aexpr_to_llvm builder ae_r in
      build_add l r "add" builder   
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

  let exp = aexpr_to_llvm llbuilder e in
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
