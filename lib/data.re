open Ezjsonm;

type t = {
  id: list(string),
  json: Ezjsonm.t,
};

let gen_iri = (host, id) => {
  switch (id) {
  | [container_id] => "http://" ++ host ++ "/annotations/" ++ container_id
  | [container_id, annotation_id] =>
    "http://"
    ++ host
    ++ "/annotations/"
    ++ container_id
    ++ "/"
    ++ annotation_id
  | _ => failwith("well that's embarassing")
  };
};

// id autogenerated or via slug
let from_post = (~data, ~id, ~host) => {
  switch (from_string(data)) {
  | exception (Parse_error(_, _)) => Result.error("could not parse JSON")
  | json =>
    if (mem(json, ["id"])) {
      Result.error("id can not be supplied");
    } else {
      let iri = gen_iri(host, id);
      let json_with_id = update(json, ["id"], Some(string(iri)));
      let json' = `O(get_dict(json_with_id));
      Result.ok({id, json: json'});
    }
  };
};

// id contained in body
let from_put = (~data, ~id, ~host) => {
  switch (from_string(data)) {
  | exception (Parse_error(_, _)) => Result.error("could not parse JSON")
  | json =>
    switch (find_opt(json, ["id"])) {
    | None => Result.error("id does not exit")
    | Some(id') =>
      let iri = gen_iri(host, id);
      switch (get_string(id')) {
      | exception (Parse_error(_, _)) => Result.error("id not string")
      | iri' =>
        if (iri == iri') {
          Result.ok({id, json});
        } else {
          Result.error("id in body does not match");
        }
      };
    }
  };
};

// accessors
let id = r => r.id;

let json = r => r.json;

// utility
let to_string = r => {
  Ezjsonm.to_string(r.json);
};
