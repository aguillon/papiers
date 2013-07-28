let (^/) = Filename.concat

let db_file =
  let home = (try Unix.getenv "HOME" with Not_found -> Filename.current_dir_name) in
  home ^/ ".papiers.db"

let external_reader = "xdg-open"

let colored_output = true

module Colors = struct
  open ANSITerminal

  let title = [Bold; Underlined]
  let authors = [green]
  let sources = [red]
  let tags = [blue]
end