# ZIG-CLI

A simple package for building command line apps in Zig.

Inspired by [urfave/cli](https://github.com/urfave/cli) Go package.

## Features
* command line arguments are parsed into zig values
* long and short options: `--option1`, `-o`
* optional `=` sign: `--address=127.0.0.1` equals `--address 127.0.0.1`
* concatenated short options: `-a -b -c` equals `-abc`
* subcommands: `command1 -option1 subcommand2 -option2`
* multiple option values: `--opt val1 --opt val2 --opt val3`
* enums as option values: `--opt EnumValue1`
* options value can be read from environment variables with a configured prefix
* positional arguments can be mixed with options: `--opt1 val1 arg1 -v`
* stops option parsing after `--`: `command -- --abc` will consider `--abc` as a positional argument to `command`.
* errors on missing required options: `ERROR: option 'ip' is required`
* prints help with `--help`
* colored help messages when TTY is attached

## Usage
```zig
const std = @import("std");
const cli = @import("zig-cli");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var config = struct {
    host: []const u8 = "localhost",
    port: u16 = undefined,
}{};

var host = cli.Option{
    .long_name = "host",
    .help = "host to listen on",
    .value_ref = cli.mkRef(&config.host),
};
var port = cli.Option{
    .long_name = "port",
    .help = "port to bind to",
    .required = true,
    .value_ref = cli.mkRef(&config.port),
};
var app = &cli.App{
    .name = "short",
    .options = &.{ &host, &port },
    .action = run_server,
};

pub fn main() !void {
    return cli.run(app, allocator);
}

fn run_server(_: []const []const u8) !void {
    std.log.debug("server is listening on {s}:{}", .{ config.host, config.port });
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