(******************************************************************************)
(*   Copyright (c) 2013-2014 Armaël Guéneau.                                  *)
(*   See the file LICENSE for copying permission.                             *)
(******************************************************************************)

open Batteries

let (++) (a, b) (u, v) = (a +. u, b +. v)

let min3 a b c =
  min a (min b c)

(* Credits to http://rosettacode.org/wiki/Levenshtein_distance#OCaml *)
let levenshtein ~del ~insert ~subst ~eq s t =
  let m = String.length s
  and n = String.length t in
    (* for all i and j, d.(i).(j) will hold the Levenshtein distance between
       the first i characters of s and the first j characters of t *)
  let d = Array.make_matrix (m+1) (n+1) 0 in

  for i = 0 to m do
    d.(i).(0) <- i  (* the distance of any first string to an empty second string *)
  done;
  for j = 0 to n do
    d.(0).(j) <- j  (* the distance of any second string to an empty first string *)
  done;

  for j = 1 to n do
    for i = 1 to m do

      if eq s.[i-1] t.[j-1] then
        d.(i).(j) <- d.(i-1).(j-1)  (* no operation required *)
      else
        d.(i).(j) <- min3
          (d.(i-1).(j) + del)   (* a deletion *)
          (d.(i).(j-1) + insert)   (* an insertion *)
          (d.(i-1).(j-1) + subst) (* a substitution *)
    done;
  done;

  d.(m).(n)


type elt =
| String of string
| Id of int
| Title of string
| Author of string
| Source of string
| Tag of string
| Lang of string

let str_of_query_elt = function
  | Id i -> "id:" ^ (string_of_int i)
  | String s -> s
  | Title s -> "title:" ^ s
  | Author s -> "author:" ^ s
  | Source s -> "source:" ^ s
  | Tag s -> "tag:" ^ s
  | Lang s -> "lang:" ^ s

type t = elt list

let eval_query_elt ?(exact_match = false) (elt: elt) (doc: Inner_db.document): float * float =
  let ldist u v =
    let d = levenshtein ~del:1 ~insert:1 ~subst:1 ~eq:(=) u v in
    let norm_d = (float_of_int d) /.
      (float_of_int (max (String.length u) (String.length v))) in
    if norm_d <= 1./.3. then 1. -. norm_d else 0.
  in

  let search u (* in *) v =
    let u = String.lowercase u and v = String.lowercase v in
    if u = v then (1., 0.)
    else if not exact_match then
      if String.Exceptionless.find v u <> None then
        (0., 1.)
      else begin
        try
          String.split_on_string ~by:" " v
          |> List.map (ldist u)
          |> List.fold_left (fun acc d -> acc ++ (0., d)) (0., 0.)
        with Not_found ->
          (0., ldist u v)
      end
    else (0., 0.)
  in

  let make_search (s: string) (l: string list) =
    List.fold_left (fun acc s' -> acc ++ (search s s')) (0., 0.) l
  in

  let open Inner_db in
  match elt with
  | Id i -> if doc.id = i then (1., 0.) else (0., 0.)
  | String s ->
    make_search s
      (List.flatten [[doc.content.name];
                     doc.content.authors;
                     List.map Source.to_string doc.content.source;
                     doc.content.tags])
  | Title s ->
    make_search s [doc.content.name]
  | Author s ->
    make_search s doc.content.authors
  | Source s ->
    make_search s (List.map Source.to_string doc.content.source)
  | Tag s ->
    make_search s doc.content.tags
  | Lang s ->
    make_search s [doc.content.lang]

let eval ?(exact_match = false) (q: t) (doc: Inner_db.document): float * float =
  let query_elts = List.map (fun elt -> eval_query_elt ~exact_match elt doc) q in
  if List.mem (0., 0.) query_elts then
    (0., 0.)
  else
    List.fold_left ( ++ ) (0., 0.) query_elts
