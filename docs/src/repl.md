# C++ REPL

CxxFork keeps the legacy experimental C++ REPL integration available, but it is
disabled by default on the Julia 1.12 baseline. Start Julia with
`CXX_ENABLE_REPL=1` to opt into this path.

When enabled, enter C++ mode from Julia's REPL by pressing `<`, and exit back to
Julia mode by pressing backspace at the beginning of the line.

Below is a screenshot of the REPL in action.

![REPL Screenshot](../screenshot.png)
