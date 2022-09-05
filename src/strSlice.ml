module Option = Stdcompat.Option

type t =
  { base : string
  ; off : int
  ; len : int
  }

let of_string ?(off = 0) base = { base; off; len = String.length base - off }
let to_string { base; off; len } = String.sub base off len
let print ppf s = Format.fprintf ppf "%S" (to_string s)
let get_offset { off; _ } = off
let length { len; _ } = len
let is_empty s = length s = 0

let offset n { base; off; len } =
  if n < 0 then invalid_arg "offset";
  let rec loop n base off len =
    if n = 0 || len = 0 then { base; off; len }
    else
      match base.[off] with
      | '\t' ->
          let ts = ((off + 4) / 4 * 4) - off in
          let b = Buffer.create len in
          Buffer.add_substring b base 0 off;
          for _ = 1 to ts do
            Buffer.add_char b ' '
          done;
          Buffer.add_substring b base (off + 1) (len - 1);
          loop n (Buffer.contents b) off (len + ts - 1)
      | _ -> loop (n - 1) base (off + 1) (len - 1)
  in
  loop n base off len

let lexbuf s = Lexing.from_string (to_string s)

let contains s1 { base; off; len } =
  let rec loop off =
    if off + String.length s1 > len then false
    else s1 = String.sub base off (String.length s1) || loop (off + 1)
  in
  loop off

let head = function
  | { len = 0; _ } -> None
  | { base; off; _ } -> Some base.[off]

let last = function
  | { len = 0; _ } -> None
  | { base; off; len } -> Some base.[off + len - 1]

let tail = function
  | { len = 0; _ } as s -> s
  | { base; off; len } -> { base; off = succ off; len = pred len }

let uncons s = head s |> Option.map (fun hd -> (hd, tail s))

let take n s =
  if n < 0 then invalid_arg "take";
  let rec loop n s =
    if n = 0 || length s = 0 then []
    else match head s with Some c -> c :: loop (pred n) (tail s) | None -> []
  in
  loop n s

let drop n s =
  if n < 0 then invalid_arg "drop";
  (* len should not be reduced below 0, as strings cannot have a negative length *)
  let len = max (s.len - n) 0 in
  (* off should not exceed the length of the base string *)
  let off = min (s.off + n) (String.length s.base) in
  { s with off; len }

let drop_last = function
  | { len = 0; _ } as s -> s
  | { base; off; len } -> { base; off; len = pred len }

let rec drop_while f s =
  match uncons s with Some (x, s') when f x -> drop_while f s' | _ -> s

let rec drop_last_while f s =
  match last s with
  | Some l when f l -> drop_last_while f (drop_last s)
  | _ -> s

let exists f s =
  let rec loop s i =
    if i >= s.len then false
    else if f s.base.[s.off + i] then true
    else loop s (succ i)
  in
  loop s 0

let for_all f s = not (exists (fun c -> not (f c)) s)

let sub ~len s =
  if len > s.len then invalid_arg "sub";
  { s with len }
