open Ezjsonm;

type t = {
  id: list(string),
  json: Ezjsonm.value,
};

let get_timestamp = () => {
  let t = Ptime_clock.now();
  Ptime.to_rfc3339(t, ~tz_offset_s=0);
};

let get_iri = (host, id) => {
  switch (id) {
  | [container_id, "main"] => host ++ "/annotations/" ++ container_id
  | [container_id, "collection", annotation_id] =>
    host ++ "/annotations/" ++ container_id ++ "/" ++ annotation_id
  | _ => failwith("well that's embarassing")
  };
};

let is_annotation = data => {
  Ezjsonm.(
    switch (find_opt(data, ["type"])) {
    | Some(`String("Annotation")) => true
    | _ => false
    }
  );
};

let is_container = data => {
  Ezjsonm.(
    switch (find_opt(data, ["type"])) {
    | Some(
        `A([`String("BasicContainer"), `String("AnnotationCollection")]),
      ) =>
      true
    | Some(
        `A([`String("AnnotationCollection"), `String("BasicContainer")]),
      ) =>
      true
    | _ => false
    }
  );
};

let post_worker = (json, id, host) =>
  if (mem(json, ["id"])) {
    Result.error("id can not be supplied");
  } else {
    let iri = get_iri(host, id);
    let timestamp = get_timestamp();
    let json = update(json, ["id"], Some(string(iri)));
    let json = update(json, ["created"], Some(string(timestamp)));
    Result.ok({id, json});
  };

// id autogenerated or via slug
let post_annotation = (~data, ~id, ~host) => {
  switch (from_string(data)) {
  | exception (Parse_error(_, _)) => Result.error("could not parse JSON")
  | json =>
    if (is_annotation(json)) {
      post_worker(json, id, host);
    } else {
      Result.error("annotation type not found");
    }
  };
};

let post_container = (~data, ~id, ~host) => {
  switch (from_string(data)) {
  | exception (Parse_error(_, _)) => Result.error("could not parse JSON")
  | json =>
    if (is_container(json)) {
      post_worker(json, id, host);
    } else {
      Result.error("container type not found");
    }
  };
};

let put_worker = (json, id, host) => {
  switch (find_opt(json, ["id"])) {
  | None => Result.error("id does not exit")
  | Some(id') =>
    let iri = get_iri(host, id);
    switch (get_string(id')) {
    | exception (Parse_error(_, _)) => Result.error("id not string")
    | iri' =>
      if (iri == iri') {
        let timestamp = get_timestamp();
        let json = update(json, ["modified"], Some(string(timestamp)));
        Result.ok({id, json});
      } else {
        Result.error("id in body does not match");
      }
    };
  };
};

// id contained in body
let put_annotation = (~data, ~id, ~host) => {
  switch (from_string(data)) {
  | exception (Parse_error(_, _)) => Result.error("could not parse JSON")
  | json =>
    if (is_annotation(json)) {
      put_worker(json, id, host);
    } else {
      Result.error("annotation type not found");
    }
  };
};

// accessors
let id = r => r.id;

let json = r => r.json;

// utility
let to_string = r => {
  Ezjsonm.value_to_string(r.json);
};
