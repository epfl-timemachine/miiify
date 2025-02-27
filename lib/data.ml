open Ezjsonm

let get_timestamp () =
  let t = Ptime_clock.now () in
  Ptime.to_rfc3339 t ~tz_offset_s:0
;;

let get_iri host id scope =
  match id with
  | [ container_id; "main" ] -> host ^ scope ^ "/annotations/" ^ container_id
  | [ container_id; "collection"; annotation_id ] ->
    host ^ scope ^ "/annotations/" ^ container_id ^ "/" ^ annotation_id
  | _ -> failwith "well that's embarassing"
;;

let has_body data = mem data [ "body" ]
let has_target data = mem data [ "target" ]

let is_annotation data =
  let open Ezjsonm in
  match find_opt data [ "type" ] with
  | Some (`String "Annotation") when has_body data && has_target data -> true
  | _ -> false
;;

let is_manifest data =
  let open Ezjsonm in
  match find_opt data [ "type" ] with
  | Some (`String "Manifest") -> true
  | _ -> false
;;

let is_container data =
  let open Ezjsonm in
  match find_opt data [ "type" ] with
  | Some (`A [ `String "BasicContainer"; `String "AnnotationCollection" ]) -> true
  | Some (`A [ `String "AnnotationCollection"; `String "BasicContainer" ]) -> true
  | _ -> false
;;

let post_worker json id host scope =
  if mem json [ "id" ]
  then Result.error "id can not be supplied"
  else (
    let iri = get_iri host id scope in
    let timestamp = get_timestamp () in
    let json = update json [ "id" ] (Some (string iri)) in
    let json = update json [ "created" ] (Some (string timestamp)) in
    Result.ok json)
;;

let post_annotation ~data ~id ~host ~scope =
  match from_string data with
  | exception Parse_error (_, _) -> Result.error "could not parse JSON"
  | json ->
    if is_annotation json
    then post_worker json id host scope
    else Result.error "annotation type not found"
;;

let post_container ~data ~id ~host ~scope =
  match from_string data with
  | exception Parse_error (_, _) -> Result.error "could not parse JSON"
  | json ->
    if is_container json
    then post_worker json id host scope
    else Result.error "container type not found"
;;

let put_annotation_worker json id host scope =
  match find_opt json [ "id" ] with
  | None -> Result.error "id does not exit"
  | Some id' ->
    let iri = get_iri host id scope in
    (match get_string id' with
    | exception Parse_error (_, _) -> Result.error "id not string"
    | iri' ->
      if iri = iri'
      then (
        let timestamp = get_timestamp () in
        let json = update json [ "modified" ] (Some (string timestamp)) in
        Result.ok json)
      else Result.error "id in body does not match")
;;

let put_annotation ~data ~id ~host ~scope =
  match from_string data with
  | exception Parse_error (_, _) -> Result.error "could not parse JSON"
  | json ->
    if is_annotation json
    then put_annotation_worker json id host scope
    else Result.error "annotation type not found"
;;

let post_manifest ~data =
  match from_string data with
  | exception Parse_error (_, _) -> Result.error "could not parse JSON"
  | json ->
    if is_manifest json then Result.ok json else Result.error "manifest type not found"
;;

let put_manifest ~data = post_manifest ~data
