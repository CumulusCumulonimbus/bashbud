# user specific generators (**USG**)

user specific generators are located in 
*BASHBUD_DIR* (which defaults to `~/.config/bashbud`) in which a directory named *generators* holds all available **USG**.

Below is an example representation of the files and directories in a **USG** (and a **SWG**)

```text
BASHBUD_DIR/
  generators/
    default/      
      __link/     
        lib/
          ERR.sh
      __templates/
        program/
          __template
          __script
        readme/
          __template
      manifest.d/
        opts.md
        envs.md
      main.sh
      manifest.md
    nextgen/      
      __link/     
        ...
      __templates/
        ...
      manifest.md
```

Two **USG** exist in the filetree above: `default` and `nextgen`.
All files and directories within the root directory of the generator (*default*) that doesn't start with two underscores are referred to in the documentation as base files.
The base files will get copied to PROJECT_DIR when the project is created with the `--new` command-line option.  

```text
PROJECT_DIR/
    manifest.d/
        opts.md
        envs.md
    main.sh
    manifest.md
```

The directory structure inside the `__link` directory will get created in PROJECT_DIR when the project is created with the `--new` command-line option. And all files found (recursively) in the `__link` directory will get hard linked (`ln`) to PROJECT_DIR.  

```text
PROJECT_DIR/
    lib/
        ERR.sh     <- linked
    manifest.d/
        opts.md
        envs.md
    main.sh
    manifest.md
```

The content of the `__templates` directory is only used when a project is updated with the `--bump` command-line option.
The `__templates` directory is actually the only part of a generator needed when a PROJECT is updated. 
Since a **PSG** can only be used to `--bump` a project, 
a **PSG** generator consists of only the `__templates` directory, renamed to `bashbud` and place in the root of *PROJECT_DIR*. 