type t;

let from_post: (~data:string, ~id:string, ~host:string) => result(t,string);

let from_put: (~data:string) => result(t, string);

let id: (t) => string;

let json: (t) => Ezjsonm.t;

let to_string: (t) => string;