/*
                                    __
                                   / _|
  __ _ _   _ _ __ ___  _ __ __ _  | |_ ___  ___ ___
 / _` | | | | '__/ _ \| '__/ _` | |  _/ _ \/ __/ __|
| (_| | |_| | | | (_) | | | (_| | | || (_) \__ \__ \
 \__,_|\__,_|_|  \___/|_|  \__,_| |_| \___/|___/___/

Copyright © 2013-2016, Mike Parker.
Copyright © 2016, 渡世白玉.
Copyright © 2018, Michael D. Parker
Copyright © 2018-2019, Aurora Free Open Source Software.
Copyright © 2018-2019, Luís Ferreira <luis@aurorafoss.org>

This file is part of the Aurora Free Open Source Software. This
organization promote free and open source software that you can
redistribute and/or modify under the terms of the GNU Lesser General
Public License Version 3 as published by the Free Software Foundation or
(at your option) any later version approved by the Aurora Free Open Source
Software Organization. The license is available in the package root path
as 'LICENSE' file. Please review the following information to ensure the
GNU Lesser General Public License version 3 requirements will be met:
https://www.gnu.org/licenses/lgpl.html .

Alternatively, this file may be used under the terms of the GNU General
Public License version 3 or later as published by the Free Software
Foundation. Please review the following information to ensure the GNU
General Public License requirements will be met:
https://www.gnu.org/licenses/gpl-3.0.html.

NOTE: All products, services or anything associated to trademarks and
service marks used or referenced on this file are the property of their
respective companies/owners or its subsidiaries. Other names and brands
may be claimed as the property of others.

For more info about intellectual property visit: aurorafoss.org or
directly send an email to: contact (at) aurorafoss.org .

This file is an improvement of an existing code, part of DerelictUtil
from DerelictOrg. Check it out at derelictorg.github.io .

This file is an improvement of an existing code, developed by 渡世白玉
and available on github at https://github.com/huntlabs/DerelictUtil .

This file is an improvement of an existing code, part of bindbc-loader
from BindBC. Check it out at github.com/BindBC/bindbc-loader .
*/

module riverd.loader;

/** Dynamic library loader
 * @file riverd/loader.d
 * @author Luís Ferreira <luis@aurorafoss.org>
 * @author Aurora Free Open Source Software
 * @author 渡世白玉
 * @author Michael D. Parker
 * @date 2013-2019
 */

public import riverd.builder;

version(Posix) import core.sys.posix.dlfcn;
else version(Windows) import core.sys.windows.windows;

import std.conv : to;
import std.traits;

@nogc nothrow {
	/** Load a dynamic library
	 * @param name complete library string name
	 */
	void* dylib_load(const(char)* name)
	{
		version(Posix) void* handle = dlopen(name, RTLD_NOW);
		else version(Windows) void* handle = LoadLibraryA(name);
		if(handle) return handle;
		else return null;
	}

	/** Bind a library symbol
	 * This function bind a specific symbol from the dynamic library.
	 * @param handle library handler
	 * @param ptr symbol pointer
	 * @param name symbol name
	 */
	void dylib_bindSymbol(void* handle, void** ptr, const(char)* name)
	{
		assert(handle);
		version(Posix) const void* sym = dlsym(handle, name);
		else version(Windows) const void* sym = GetProcAddress(handle, name);

		*ptr = cast(void*)sym;
	}

	/** Reports dynamic library errors
	 * @param buf char buffer
	 * @param len buffer length
	 */
	void dylib_sysError(char* buf, size_t len)
	{
		import core.stdc.string : strncpy;
		version(Windows) {
			char* msgBuf;
			enum uint langID = MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT);

			FormatMessageA(
				FORMAT_MESSAGE_ALLOCATE_BUFFER |
				FORMAT_MESSAGE_FROM_SYSTEM |
				FORMAT_MESSAGE_IGNORE_INSERTS,
				null,
				GetLastError(),
				langID,
				cast(char*)&msgBuf,
				0,
				null
			);

			if(msgBuf) {
				strncpy(buf, msgBuf, len);
				buf[len - 1] = 0;
				LocalFree(msgBuf);
			}
			else strncpy(buf, "Unknown Error\0", len);
		}
		else version(Posix) {
			char* msg = dlerror();
			strncpy(buf, msg != null ? msg : "Unknown Error", len);
			buf[len - 1] = 0;
		}
	}
}
version(D_BetterC) {
	/** Unload a dynamic library
	 * @param handle dynamic library handler
	 */
	@nogc nothrow void dylib_unload(void* handle)
	{
		if(handle) {
			version(Posix) dlclose(handle);
			else version(Windows) FreeLibrary(handle);
			handle = null;
		}
	}
}
else {
	import std.array;
	import std.string;

	/** Dynamic Library Version struct */
	struct DylibVersion
	{
		uint major; /** major version number */
		uint minor; /** minor version number */
		uint patch; /** patch version number */
	}

	/** Dynamic Library Loader Exception
	 * This exception is thrown when the library can't be loaded
	 */
	class DylibLoadException : Exception
	{

		/** Dynamic Library Loader Exception constructor
		 * @param msg exception message
		 * @param line line number in code
		 * @param file code file
	 	 */
		this(string msg, size_t line = __LINE__, string file = __FILE__)
		{
			super(msg, file, line, null);
		}

		/** Dynamic Library Loader Exception constructor
		 * @param names libraries name
		 * @param reasons reasons why it can't load
		 * @param line line number in code
		 * @param file code file
	 	 */
		this(string[] names, string[] reasons, size_t line = __LINE__, string file = __FILE__)
		{
			string msg = "Failed to load one or more shared libraries:";
			foreach(i, name; names) {
				msg ~= "\n\t" ~ name ~ " - ";
				if(i < reasons.length)
					msg ~= reasons[i];
				else
					msg ~= "Unknown";
			}
			this(msg, line, file);
		}

		/** Dynamic Library Loader Exception constructor
		 * @param msg exception message
		 * @param name library name
		 * @param line line number in code
		 * @param file code file
	 	 */
		this(string msg, string name = "", size_t line = __LINE__, string file = __FILE__)
		{
			super(msg, file, line, null);
			_name = name;
		}

		/** Get the library name */
		pure nothrow @nogc
		@property string name()
		{
			return _name;
		}

		private string _name; /** library name */
	}


	class DylibSymbolLoadException : Exception
	{

		this(string msg, size_t line = __LINE__, string file = __FILE__) {
			super(msg, file, line, null);
		}

		this(string lib, string symbol, size_t line = __LINE__, string file = __FILE__)
		{
			_lib = lib;
			_symbol = symbol;
			this("Failed to load symbol " ~ symbol ~ " from shared library " ~ lib, line, file);
		}

		@property string lib()
		{
			return _lib;
		}

		@property string symbol()
		{
			return _symbol;
		}

	private:
		string _lib;
		string _symbol;
	}

	pure struct Dylib
	{
		void load(string[] names)
		{
			if(isLoaded)
				return;

			string[] fnames;
			string[] freasons;

			foreach(name; names)
			{
				import std.stdio;
				import std.conv;

				version(Posix) _handle = dlopen(name.toStringz(), RTLD_NOW);
				else version(Windows) _handle = LoadLibraryA(name.toStringz());
				if(isLoaded) {
					_name = name;
					break;
				}

				fnames ~= name;

				import std.conv : to;

				version(Posix) {
					string err = to!string(dlerror());
					if(err is null)
						err = "Unknown error";
				}
				else version(Windows)
				{
					import std.windows.syserror;
					string err = sysErrorString(GetLastError());
				}

				freasons ~= err;
			}
			if(!isLoaded)
				throw new DylibLoadException(fnames, freasons);
		}

		void* loadSymbol(string name, bool required = true)
		{
			version(Posix) void* sym = dlsym(_handle, name.toStringz());
			else version(Windows) void* sym = GetProcAddress(_handle, name.toStringz());

			if(required && !sym)
			{
				if(_callback !is null)
					required = _callback(name);
				if(required)
					throw new DylibSymbolLoadException(_name, name);
			}

			return sym;
		}

		void unload()
		{
			if(isLoaded)
			{
				version(Posix) dlclose(_handle);
				else version(Windows) FreeLibrary(_handle);
				_handle = null;
			}
		}

		@property bool isLoaded()
		{
			return _handle !is null;
		}

		@property bool delegate(string) missingSymbolCallback()
		{
			return _callback;
		}

		@property void missingSymbolCallback(bool delegate(string) callback)
		{
			_callback = callback;
		}

		@property void missingSymbolCallback(bool function(string) callback)
		{
			import std.functional : toDelegate;
			_callback = toDelegate(callback);
		}

	private:
		string _name;
		void* _handle;
		bool delegate(string) _callback;
	}

	abstract class DylibLoader
	{
		this(string libs)
		{
			string[] libs_ = libs.split(",");
			foreach(ref string l; libs_)
				l = l.strip();
			this(libs_);
		}

		this(string[] libs)
		{
			_libs = libs;
			dylib.load(_libs);
			loadSymbols();
		}

		final this(string[] libs, DylibVersion ver)
		{
			configureMinimumVersion(ver);
			this(libs);
		}

		final this(string libs, DylibVersion ver)
		{
			configureMinimumVersion(ver);
			this(libs);
		}

		protected void loadSymbols() {}

		protected void configureMinimumVersion(DylibVersion minVersion)
		{
			assert(0, "DylibVersion is not supported by this loader.");
		}

		protected final void bindFunc(void** ptr, string name, bool required = true)
		{
			void* func = dylib.loadSymbol(name, required);
			*ptr = func;
		}

		protected final void bindFunc(TFUN)(ref TFUN fun, string name, bool required = true)
			if(isFunctionPointer!(TFUN))
		{
			void* func = dylib.loadSymbol(name, required);
			fun = cast(TFUN)func;
		}

		protected final void bindFunc_stdcall(Func)(ref Func f, string unmangledName)
		{
			version(Win32) {
				import std.format : format;
				import std.traits : ParameterTypeTuple;

				// get type-tuple of parameters
				ParameterTypeTuple!f params;

				size_t sizeOfParametersOnStack(A...)(A args)
				{
					size_t sum = 0;
					foreach (arg; args) {
						sum += arg.sizeof;

						// align on 32-bit stack
						if (sum % 4 != 0)
							sum += 4 - (sum % 4);
					}
					return sum;
				}
				unmangledName = format("_%s@%s", unmangledName, sizeOfParametersOnStack(params));
			}
			bindFunc(cast(void**)&f, unmangledName);
		}

		@property final string[] libs()
		{
			return _libs;
		}

		Dylib dylib;
		private string[] _libs;
	}

	pragma(inline, true) void dylib_unload(void* handle)
	{
		(cast(DylibLoader)handle).dylib.unload();
	}
}

pragma(inline, true) bool dylib_is_loaded(void* handle)
{
	version(D_BetterC) return !(handle is null);
	else return (cast(DylibLoader)handle).dylib.isLoaded();
}
