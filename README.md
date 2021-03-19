# Alloverse app template

This is an Alloverse app. You can 
[read about making apps](https://alloverse.com/develop-apps/)
on Alloverse's website.

__psst, you should summarize and explain your project here!__

## Developing

Application sources are in `lua/`.

To start the app and connect it to an Alloplace for testing, run

```
./allo/assist run alloplace://nevyn.places.alloverse.com
```

## Documentation

We're still working on setting up a comprehensive documentation web site. Some initial documentation
is provided in your `lua/main.lua`.

The implementation of the UI library has documentation inline which you can use while we're
working on the docs website. Navigate to `allo/deps/alloui/lua/alloui` and have a look at the various
lua files in there, and in particular the various UI elements under `views`. Some various views include:

* Surface, a flat surface to put stuff on
* Label, for displaying text
* Button, for clicking on
* Navstack, for drilling into nested data
