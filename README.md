# ZIG-CLI
[![Zig Docs](https://img.shields.io/badge/docs-zig-%23f7a41d)](https://sam701.github.io/zig-cli)


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
const cli = @import("cli");

// Define a configuration structure with default values.
var config = struct {
    host: []const u8 = "localhost",
    port: u16 = undefined,
}{};

pub fn main() !void {
    var r = try cli.AppRunner.init(std.heap.page_allocator);

    // Create an App with a command named "short" that takes host and port options.
    const app = cli.App{
        .command = cli.Command{
            .name = "short",
            .options = try r.allocOptions(&.{
                // Define an Option for the "host" command-line argument.
                .{
                    .long_name = "host",
                    .help = "host to listen on",
                    .value_ref = r.mkRef(&config.host),
                },

                // Define an Option for the "port" command-line argument.
                .{
                    .long_name = "port",
                    .help = "port to bind to",
                    .required = true,
                    .value_ref = r.mkRef(&config.port),
                },
            }),
            .target = cli.CommandTarget{
                .action = cli.CommandAction{ .exec = run_server },
            },
        },
    };
    return r.run(&app);
}

// Action function to execute when the "short" command is invoked.
fn run_server() !void {
    // Log a debug message indicating the server is listening on the specified host and port.
    std.log.debug("server is listening on {s}:{d}", .{ config.host, config.port });
}
```

### Using with the Zig package manager
Add `cli` to your `build.zig.zon`
```
zig fetch --save git+https://github.com/sam701/zig-cli
```
See the [`standalone`](./examples/standalone) example in the `examples` folder.

## Printing help
See [`simple.zig`](./examples/simple.zig)

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
