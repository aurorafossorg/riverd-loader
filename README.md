# RiverD Core
A cross-platform betterC compatible shared library loader for D bindings

RiverD is a project to create static and dynamic binds to all C libraries. The intent is to make a standard loader and allow users to use or not `-betterC`, `@nogc` or even `nothrow`.

## Use RiverD
### How to create a RiverD bind

At the moment, our mixin builder don't support `-betterC`, so you need to make it manually (D compilers can't evaluate CTFE with GC dependent code using `-betterC`).

Using RiverD builder, you need to specify a `types` module containing all the types to be used on your C functions, a `dynfun` module containing `__gshared` symbols and import to `types` (for function types), a `dynload` module containing the import of `dynfun` module and this piece of code:
```d
mixin(DylibLoaderBuilder!(dynfun));
```
Additionally, you have `statfun` module for static linkage support containing `extern(C)` functions declarations.

Using RiverD loader manually you can adapt this code for `dynload` module:
```d
void* dylib_load_libname() {
	void* handle = dylib_load("libname.so");
	if(handle is null) return null;

	dylib_bindSymbol(handle, cast(void**)&libname_symbol, "libname_symbol"); //make this for every function symbol

	return handle;
}
```

### How to load/unload a bind
```d
void* libname_handle = dylib_load_libname(); // load
dylib_unload(libname_handle); // unload
bool loaded = dylib_is_loaded(libname_handle); // isloaded
```
# How to contribute
Check out our [wiki](https://wiki.aurorafoss.org/).

# License
GNU Lesser General Public License (Version 3, 29 June 2007)

---
Made with ❤ by a bunch of geeks

[![License](https://img.shields.io/badge/license-LGPLv3-lightgrey.svg)](https://www.gnu.org/licenses/lgpl-3.0.html) [![Discord Server](https://discordapp.com/api/guilds/350229534832066572/embed.png)](https://discord.gg/4YuxJj)
