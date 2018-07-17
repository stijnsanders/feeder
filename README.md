# feeder
A simple RSS/Atom feed reader, just the way I like it (and hope you do to).

Try it here:
* http://yoy.be/home/feeder/

See also
* http://yoy.be/xxm
* https://github.com/stijnsanders/DataLank

----

## developer notes

_feeder_ for the moment, in an attempt to avoid including a full account management sub-system here, uses a link to _tx_ for user authentication. To get going on a version for yourself that doesn't require _tx_, in unit `xxmSession.pas` change `UserID:=0;` to `UserID:=1;` and create a record in table `User` for yourself.