# gpac

A GPA Calculator CLI for NUS/NTU students to calculate their GPA and simulate S/U options.

Note: this CLI has only been tested in Arch Linux systems, but should work on any Linux system. Can't say the same for windows :)

## Installation

### Installing pre-built escript file via package manager

#### Arch

Run the following commands:

```sh
sudo pacman -S git base-devel
git clone https://github.com/David-The-Programmer/gpac-install.git
cd gpac-install
makepkg -si
```

## Usage

Run `gpac --help` to get an brief overview of all subcommands.

Run `gpac <subcommand> --help` to get more information on each subcommand.

## Development

Ensure you have [erlang](https://www.erlang.org/downloads), [gleam](https://gleam.run/getting-started/installing/) installed.

For Arch users, ensure you install [rebar3](https://archlinux.org/packages/extra/any/rebar3/) as well, it does not get installed automatically when installing gleam.

Using pacman:
```sh
sudo pacman -S erlang gleam rebar3
```

Use yay:
```sh
yay -S erlang gleam rebar3
```

Clone this repository via HTTPS
```sh
git clone https://github.com/David-The-Programmer/gpac.git
```

Or via SSH
```sh
git clone git@github.com:David-The-Programmer/gpac.git
```

To create the escript file to run the `gpac` CLI , run the following commands:

```sh
gleam build

gleam run -m gleescript
```
Subsequently, run `./gpac <COMMAND>` to use the CLI application

To test, run the following command:
```sh
gleam test
```
