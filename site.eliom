[%%shared
open Eliom_lib
open Eliom_content
open Html.D
]

module Site_app =
  Eliom_registration.App (
  struct
    let application_name = "site"
    let global_data_path = None
  end)

let main_service =
  Eliom_service.create
    ~path:(Eliom_service.Path [])
    ~meth:(Eliom_service.Get Eliom_parameter.unit)
    ()

let () =
  Site_app.register
    ~service:main_service
    (fun () () ->
       Lwt.return
         (Eliom_tools.F.html
            ~title:"site"
            ~css:[["css";"site.css"]]
            Html.F.(body [
              h1 [txt "Welcome from Eliom's distillery!"];
            ])))
