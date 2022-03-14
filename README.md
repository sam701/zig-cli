# ZIG-CLI

A simple package for building command line apps in Zig.

Inspired by [urfave/cli](https://github.com/urfave/cli) Go package.

## Usage
See [`simple.zig`](./example/simple.zig)

```
$ ./zig-out/bin/example sub1 --help
USAGE:
  abc sub1 [OPTIONS]

another awesome command

this is my awesome multiline description.
This is already line 2.
And this is line 3.

COMMANDS:
  sub2   sub2 help

OPTIONS:
  -i, --ip <IP>         this is the IP address
      --int <VALUE>     this is an int
      --bool            this is a bool
      --float <VALUE>   this is a float
  -h, --help            Prints help information
```

## Features
* long and short options: `--option1`, `-o`
* optional `=` sign: `--address=127.0.0.1` equals `--address 127.0.0.1`
* concatenated short options: `-a -b -c` equals `-abc`
* subcommands: `command1 -option1 subcommand2 -option2`
* stop optoin parsing after `--`: `command -- --abc` will consider `--abc` as an argument to `command`.

## License
MIT