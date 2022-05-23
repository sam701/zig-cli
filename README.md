# ZIG-CLI

A simple package for building command line apps in Zig.

Inspired by [urfave/cli](https://github.com/urfave/cli) Go package.

## Features
* long and short options: `--option1`, `-o`
* optional `=` sign: `--address=127.0.0.1` equals `--address 127.0.0.1`
* concatenated short options: `-a -b -c` equals `-abc`
* subcommands: `command1 -option1 subcommand2 -option2`
* multiple option values: `--opt val1 --opt val2 --opt val3`
* stops option parsing after `--`: `command -- --abc` will consider `--abc` as an argument to `command`.
* errors on missing required options: `ERROR: option 'ip' is required`
* prints help with `--help`

## Usage
```zig
const std = @import("std");
const cli = @import("zig-cli");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var host = cli.Option{
    .long_name = "host",
    .help = "host to listen on",
    .value = cli.OptionValue{ .string = null },
};
var port = cli.Option{
    .long_name = "port",
    .help = "port to bind to",
    .value = cli.OptionValue{ .int = null },
};
var app = &cli.Command{
    .name = "run",
    .help = "run the server",
    .options = &.{&host, &port},
    .action = run_server,
};

pub fn main() !void {
    return cli.run(app, allocator);
}

fn run_server(_: []const []const u8) !void {
    var h = host.value.string.?;
    var p = port.value.int.?;
    std.log.debug("server is listening on {s}:{}", .{ h, p });
}
```

## Printing help
See [`simple.zig`](./example/simple.zig)

```
$ ./zig-out/bin/simple sub1 --help
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

## License
MIT