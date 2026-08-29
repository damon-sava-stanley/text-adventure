# Examples

## Minimal persistent game

[`minimal`](minimal) is the smallest playable vertical slice of the toolkit.
It defines a Persistent ontology, seeds a Kitchen and portable Toaster, parses
`take <thing>`, decides whether the command is allowed, applies a typed event,
and describes the post-event state. Every turn runs through the public engine
API in one SQLite transaction.

Run it with a file-backed database:

```console
cabal run text-adventure-example-minimal -- ./minimal.sqlite
```

The same database can be reused across runs; the Toaster remains carried after
the process exits. Use a new database path to start with a fresh world.

```console
$ cabal run text-adventure-example-minimal -- ./minimal.sqlite
The Toaster awaits in the Kitchen. Type 'quit' to leave.
> take toaster
You take the Toaster.
> take toaster
You are already carrying the Toaster.
> take kettle
There is no Kettle here.
> dance
I don't understand that.
> quit
Goodbye.
```

`quit` and end-of-file are handled by the console frontend, outside the game
world's command grammar.
