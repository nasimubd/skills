# typeless-migrate maintainer notes

The plugin is local-first and archive-oriented. It must never copy Typeless session stores,
cookies, account billing/team data, or sync cursors. It must refuse to overwrite an archive,
reject recording paths outside the source Recordings directory, and default to dry-run.
Private Typeless endpoints and request-signature emulation are deliberately out of scope.
