# zig-cli

[![Zig Docs](https://img.shields.io/badge/docs-zig-%23f7a41d)](https://sam701.github.io/zig-cli)

A simple package for building command line apps in Zig.

Inspired by [urfave/cli](https://github.com/urfave/cli) Go package.

## Features

- Arguments parsed directly into Zig values
- Long and short options: `--option`, `-o`
- Optional `=` sign: `--address=127.0.0.1` equals `--address 127.0.0.1`
- Concatenated short options: `-a -b -c` equals `-abc`
- Subcommands: `cmd -opt subcmd -opt2`
- Multiple option values: `--opt val1 --opt val2 --opt val3`
- Enums as option values: `--opt EnumValue1`
- Positional arguments (required and optional), mixed with options: `--opt val arg1 -v`
- Option values read from environment variables with a configured prefix
- Stops option parsing after `--`: `cmd -- --abc` treats `--abc` as a positional argument
- Errors on missing required options: `ERROR: missing required option '--port'`
- App version and author metadata
- Built-in `--help` flag with colored output when a TTY is attached

## Usage

[API Documentation](https://sam701.github.io/zig-cli)

```zig
const std = @import("std");
const cli = @import("cli");

var config = struct {
    host: []const u8 = "localhost",
    port: u16 = undefined,
}{};

pub fn main(init: std.process.Init) !void {
    var r = cli.AppRunner.init(&init);
    defer r.deinit();

    const app = cli.App{
        .command = cli.Command{
            .name = "server",
            .options = try r.allocOptions(&.{
                .{
                    .long_name = "host",
                    .help = "host to listen on",
                    .value_ref = r.mkRef(&config.host),
                },
                .{
                    .long_name = "port",
                    .help = "port to bind to",
                    .required = true,
                    .value_ref = r.mkRef(&config.port),
                },
            }),
            .target = cli.CommandTarget{
                .action = cli.CommandAction{ .exec = run },
            },
        },
    };
    return r.run(&app);
}

fn run() !void {
    std.log.info("listening on {s}:{d}", .{ config.host, config.port });
}
```

### Installing with the Zig package manager

**1. Fetch the package:**

```sh
# For zig master and zig 0.16
zig fetch --save git+https://github.com/sam701/zig-cli

# For zig 0.15
zig fetch --save git+https://github.com/sam701/zig-cli#zig-0.15
```

**2. Wire it up in `build.zig`:**

```zig
const cli_dep = b.dependency("cli", .{});
exe.root_module.addImport("cli", cli_dep.module("cli"));
```

## Help output

See [`simple.zig`](./examples/simple.zig) for a full example with subcommands.

```
$ ./zig-out/bin/simple sub1 --help
USAGE:
  simple sub1 [OPTIONS]

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
