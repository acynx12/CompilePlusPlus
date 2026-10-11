# Compile++

![Uploading image.png…]()

Compile++ is a small **vibe-coded** native macOS C++ IDE. It embeds real terminal sessions for Vim, build output, and GDB.

AI Model Used: ChatGPT-5.6

## Use

1. Launch `Compile++.app` and create a new C++ source file or choose an existing one.
2. Edit in Vim in the left pane.
3. Click **Compile & Run** (or press Command-B). For `a.cpp`, Compile++ runs:

   ```sh
   g++ a.cpp -g -o a && ./a
   ```

4. Click the collapsed **Debugger** bar to run `gdb ./a` in the lower pane. Drag the horizontal divider to give GDB more or less room.

The right pane is replaced with a fresh terminal each time you compile, so compiler diagnostics and program input/output are interactive.

The Vim and output panes follow the window width and preserve their relative sizes when the window is resized or zoomed. When Vim exits normally, Compile++ returns to its empty welcome state. When GDB exits, its lower panel closes automatically. Opening or creating another file, or quitting Compile++, first sends `Escape` and `:wq` to Vim so changes are saved before the transition.

Choose **Compile++ → Settings…** (Command-comma) to switch between the persistent Black and White themes.

## Build from source

Requires macOS 13 or newer and Xcode command-line tools. The terminal component, SwiftTerm, is vendored under `Vendor/` so the project builds without downloading packages.

```sh
chmod +x build-app.sh
./build-app.sh
open 'dist/Compile++.app'
```

## GDB on macOS

macOS includes LLDB but not GDB. Install GDB with Homebrew (`brew install gdb`) and complete the code-signing setup Homebrew describes. If GDB is unavailable, the debugger pane explains this and opens a shell instead.

## Third-party source

This project includes SwiftTerm by Miguel de Icaza and contributors under the MIT License. Its license is at `Vendor/SwiftTerm/LICENSE`.
