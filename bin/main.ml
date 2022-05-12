open Miiify
open Lwt.Infix

let welcome_message = "Welcome to Miiify!"
let version_message = "0.1.1"

type t = { config : Config_t.config; db : Db.t; container : Container.t }

let get_annotation ctx request =
  let open Response in
  let container_id = Dream.param request "container_id" in
  let annotation_id = Dream.param request "annotation_id" in
  let key = [ container_id; "collection"; annotation_id ] in
  Container.get_hash ~db:ctx.db ~key >>= function
  | Some hash -> (
      match Header.get_if_none_match request with
      | Some etag when hash = etag -> empty_response `Not_Modified
      | _ ->
          Db.get ~ctx:ctx.db ~key >>= fun body ->
          json_response ~request ~body ~etag:(Some hash) ())
  | None -> error_response `Not_Found "annotation not found"

let get_annotation_pages ctx request =
  let open Response in
  let container_id = Dream.param request "container_id" in
  let key = [ container_id; "main" ] in
  let page = Container.get_page request in
  let prefer = Header.get_prefer request ctx.config.container_representation in
  Container.set_representation ~ctx:ctx.container ~representation:prefer;
  Container.get_hash ~db:ctx.db ~key >>= function
  | Some hash -> (
      match Header.get_if_none_match request with
      | Some etag when hash = etag -> empty_response `Not_Modified
      | _ -> (
          Container.get_annotation_page ~ctx:ctx.container ~db:ctx.db ~key ~page
          >>= fun page ->
          match page with
          | Some page -> json_response ~request ~body:page ~etag:(Some hash) ()
          | None -> error_response `Not_Found "page not found"))
  | None -> error_response `Not_Found "container not found"

let get_annotation_collection ctx request =
  let open Response in
  let container_id = Dream.param request "container_id" in
  let prefer = Header.get_prefer request ctx.config.container_representation in
  Container.set_representation ~ctx:ctx.container ~representation:prefer;
  let key = [ container_id; "main" ] in
  Container.get_hash ~db:ctx.db ~key >>= function
  | Some hash -> (
      match Header.get_if_none_match request with
      | Some etag when hash = etag -> empty_response `Not_Modified
      | _ ->
          Container.get_annotation_collection ~ctx:ctx.container ~db:ctx.db ~key
          >>= fun body -> json_response ~request ~body ~etag:(Some hash) ())
  | None -> error_response `Not_Found "container not found"

let delete_container ctx request =
  let open Response in
  let container_id = Dream.param request "container_id" in
  let key = [ container_id ] in
  let main_key = [ container_id; "main" ] in
  Container.get_hash ~db:ctx.db ~key:main_key >>= function
  | Some hash -> (
      match Header.get_if_match request with
      | Some etag when hash = etag ->
          Container.delete_container ~db:ctx.db ~key
            ~message:("DELETE " ^ Utils.key_to_string key)
          >>= fun () -> empty_response `No_Content
      | None ->
          Container.delete_container ~db:ctx.db ~key
            ~message:("DELETE without etag " ^ Utils.key_to_string key)
          >>= fun () -> empty_response `No_Content
      | _ -> empty_response `Precondition_Failed)
  | None -> error_response `Not_Found "container not found"

let post_container ctx request =
  let open Response in
  match Header.get_host request with
  | None -> error_response `Bad_Request "No host header"
  | Some host -> (
      Dream.body request >>= fun body ->
      Data.post_container ~data:body ~id:[ Header.get_id request; "main" ] ~host
      |> function
      | Error m -> error_response `Bad_Request m
      | Ok data ->
          let key = Data.id data in
          let json = Data.json data in
          Container.container_exists ~db:ctx.db ~key >>= fun yes ->
          if yes then error_response `Bad_Request "container already exists"
          else
            Container.add_container ~db:ctx.db ~key ~json
              ~message:("POST " ^ Utils.key_to_string key)
            >>= fun () -> json_response ~request ~body:json ())

let delete_annotation ctx request =
  let open Response in
  let container_id = Dream.param request "container_id" in
  let annotation_id = Dream.param request "annotation_id" in
  let key = [ container_id; "collection"; annotation_id ] in
  Container.get_hash ~db:ctx.db ~key >>= function
  | Some hash -> (
      match Header.get_if_match request with
      | Some etag when hash = etag ->
          Container.delete_annotation ~db:ctx.db ~key ~container_id
            ~message:("DELETE " ^ Utils.key_to_string key)
          >>= fun () -> empty_response `No_Content
      | None ->
          Container.delete_annotation ~db:ctx.db ~key ~container_id
            ~message:("DELETE without etag " ^ Utils.key_to_string key)
          >>= fun () -> empty_response `No_Content
      | _ -> empty_response `Precondition_Failed)
  | None -> error_response `Not_Found "annotation not found"

let post_annotation ctx request =
  let open Response in
  match Header.get_host request with
  | None -> error_response `Bad_Request "No host header"
  | Some host -> (
      Dream.body request >>= fun body ->
      let container_id = Dream.param request "container_id" in
      Data.post_annotation ~data:body
        ~id:[ container_id; "collection"; Header.get_id request ]
        ~host
      |> function
      | Error m -> error_response `Bad_Request m
      | Ok data ->
          let key = Data.id data in
          let json = Data.json data in
          Container.container_exists ~db:ctx.db ~key:[ container_id ]
          >>= fun yes ->
          if yes then
            Container.annotation_exists ~db:ctx.db ~key >>= fun yes ->
            if yes then error_response `Bad_Request "annotation already exists"
            else
              Container.add_annotation ~db:ctx.db ~key ~container_id ~json
                ~message:("POST " ^ Utils.key_to_string key)
              >>= fun () -> json_response ~request ~body:json ()
          else error_response `Bad_Request "container does not exist")

let put_annotation ctx request =
  let open Response in
  match Header.get_host request with
  | None -> error_response `Bad_Request "No host header"
  | Some host -> (
      Dream.body request >>= fun body ->
      let container_id = Dream.param request "container_id" in
      let annotation_id = Dream.param request "annotation_id" in
      let key = [ container_id; "collection"; annotation_id ] in
      Data.put_annotation ~data:body ~id:key ~host |> function
      | Error m -> error_response `Bad_Request m
      | Ok data -> (
          let json = Data.json data in
          Container.get_hash ~db:ctx.db ~key >>= function
          | Some hash -> (
              match Header.get_if_match request with
              | Some etag when hash = etag ->
                  Container.update_annotation ~db:ctx.db ~key ~container_id
                    ~json
                    ~message:("PUT " ^ Utils.key_to_string key)
                  >>= fun () -> json_response ~request ~body:json ()
              | None ->
                  Container.update_annotation ~db:ctx.db ~key ~container_id
                    ~json
                    ~message:("PUT without etag " ^ Utils.key_to_string key)
                  >>= fun () -> json_response ~request ~body:json ()
              | _ -> empty_response `Precondition_Failed)
          | None -> error_response `Bad_Request "annotation not found"))

let run ctx =
  let open Response in
  Dream.run ~interface:ctx.config.interface ~tls:ctx.config.tls
    ~port:ctx.config.port ~certificate_file:ctx.config.certificate_file
    ~key_file:ctx.config.key_file
  @@ Dream.logger
  @@ Dream.router
       [
         Dream.options "/" (fun _ ->
             options_response [ "OPTIONS"; "HEAD"; "GET" ]);
         Dream.head "/" (html_response welcome_message);
         Dream.get "/" (html_response welcome_message);
         Dream.options "/version" (fun _ ->
             options_response [ "OPTIONS"; "HEAD"; "GET" ]);
         Dream.head "/version" (html_response version_message);
         Dream.get "/version" (html_response version_message);
         Dream.options "/annotations/" (fun _ ->
             options_response [ "OPTIONS"; "POST" ]);
         Dream.post "/annotations/" (post_container ctx);
         Dream.options "/annotations/:container_id/:annotation_id" (fun _ ->
             options_response [ "OPTIONS"; "HEAD"; "GET"; "PUT"; "DELETE" ]);
         Dream.head "/annotations/:container_id/:annotation_id"
           (get_annotation ctx);
         Dream.get "/annotations/:container_id/:annotation_id"
           (get_annotation ctx);
         Dream.put "/annotations/:container_id/:annotation_id"
           (put_annotation ctx);
         Dream.delete "/annotations/:container_id/:annotation_id"
           (delete_annotation ctx);
         Dream.options "/annotations/:container_id/" (fun _ ->
             options_response [ "OPTIONS"; "HEAD"; "GET"; "POST"; "DELETE" ]);
         Dream.head "/annotations/:container_id/"
           (get_annotation_collection ctx);
         Dream.get "/annotations/:container_id/" (get_annotation_collection ctx);
         Dream.post "/annotations/:container_id/" (post_annotation ctx);
         Dream.delete "/annotations/:container_id/" (delete_container ctx);
         Dream.options "/annotations/:container_id" (fun _ ->
             options_response [ "OPTIONS"; "HEAD"; "GET" ]);
         Dream.head "/annotations/:container_id" (get_annotation_pages ctx);
         Dream.get "/annotations/:container_id" (get_annotation_pages ctx);
       ]

let init config =
  {
    config;
    db =
      Db.create ~fname:config.repository_name ~author:config.repository_author;
    container =
      Container.create ~page_limit:config.container_page_limit
        ~representation:config.container_representation;
  }

let config_file = ref ""

let parse_cmdline () =
  let usage = "usage: " ^ Sys.argv.(0) in
  let speclist =
    [
      ( "--config",
        Arg.Set_string config_file,
        ": to specify the configuration file to use" );
    ]
  in
  Arg.parse speclist (fun x -> raise (Arg.Bad ("Bad argument : " ^ x))) usage

let configure () =
  parse_cmdline ();
  let data =
    match !config_file with "" -> "{}" | fname -> Utils.read_file fname
  in
  match Config.parse ~data with
  | Error message -> failwith message
  | Ok config -> run (init config)

let () = configure ()
