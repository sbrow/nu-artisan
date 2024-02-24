#!/usr/bin/env nu
# vim: set ft=nu:

# Completes Laravel artisan commands.
def main [spans: list] {
  cd ($env.PWD | find-laravel-dir);

  let filteredSpans = $spans | skip while { |it|
    $it == 'artisan' or $it == 'php'
  };

  if ($filteredSpans | length) == 1 {
    complete command-name ($filteredSpans | first)
  } else {
    complete command-arguments $filteredSpans
  }
}

# Run a laravel artisan command.
export def artisan [ ...command: string] {
  let dir = $env.PWD | find-laravel-dir;

  cd $dir;

  ^php artisan ...$command
}

export def artisan-completer [
  prev: closure
]: nothing -> closure {
  {|spans|
    if ($spans.0 == 'artisan' or $spans.0 == 'php' and $spans.1 == 'artisan') {
      main $spans
    } else {
      do $prev $spans
    }
  }
}

export def "artisan-commands" []: nothing -> table {
  php ($env.PWD | path join artisan) list --format=json
  | from json
  | get commands
  | where hidden == false
  | each {
    {
      name: $in.name
      description: $in.description
      arguments: ($in.definition.arguments | values)
      options: ($in.definition.options | values)
    }
  }
}

export def "complete command-name" [ command: string ] {
  cached-artisan-commands ['name', 'description']
  #| select name description
  | rename value
  | where { $in.value | str starts-with $command }
}

def "complete command-arguments" [ spans: list<string> ] {
  cached-artisan-commands ['*']
  | where name == $spans.0
  | first | get arguments | from json | select name description | rename value
}

# Returns the first directory in the path that contains an artisan file.
def find-laravel-dir []: string -> string {
  let path = $in;
  let artisan_path = $path | path join artisan;

  if ($artisan_path | path type) == 'file' {
    $path
  } else if ($path | path basename | is-empty) {
    error make { msg: 'artisan not found. Are you in a Laravel directory?' }
  } else {
     $path | path dirname | find-laravel-dir
  }
}

export def cached-artisan-commands [columns: list<string>] {
  let table = $env.PWD | path join artisan | str replace --all -r '[/\.]' '_';

  if (stor open | schema | get tables | columns | all { $in != $table }) {
    artisan-create-table
  }

  stor open | query db $'select ($columns | str join ", ") from ($table)'
}

export def "artisan-create-table" [] {
  let table = $env.PWD | path join artisan | str replace --all -r '[/\.]' '_';

  rm -f commands.db
  nix run nixpkgs#sqlite -- commands.db $"create table ($table) \(name TEXT PRIMARY KEY NOT NULL, description TEXT, arguments TEXT, options TEXT);"

  stor import -f commands.db
  rm commands.db

  artisan-commands | each { |it|
    stor insert -t $table -d {
      name: $in.name
      description: ($in.description | str replace -a "'" "''")
      arguments: ($in.arguments | to json -r | str replace -a -r "'" "''")
      options: ($in.options | to json -r | str replace -a -r "'" "''")
    }
  };
}
