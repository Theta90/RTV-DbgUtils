## Setup

Install the RTV-ModBuilder as a dev dependency via:

```sh

npm i -D "github:Theta90/RTV-ModBuilder#main"

```

## How It Works

This script (index.js) serves as the build entry point for the mod. Running it (e.g., via F5
or `node index.js`) will invoke the RTV-ModBuilder and produce the final mod output
in the configured output directory.

## Usage

The index.js file must be tailored to each specific project.
See [the RTV-ModBuilder documentation](https://github.com/Theta90/RTV-ModBuilder?tab=readme-ov-file#usage)
for more information on how to configure the mod builder for your specific project.

## Example Output Structure

This example's HelloWorld.vmz has the following structure:

```
HelloWorld.vmz
├── mod.txt
├── mods
│   └── HelloWorld
│       └── Main.gd
│       └── README.md
│       └── Scripts
│           └── Character.gd

```
