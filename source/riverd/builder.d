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

module riverd.builder;

template DylibLoaderBuilder(string handle_name, string[] libs, alias T, bool required = false)
{
	string _buildLoader(string handle_name, string[] libs, alias T, bool required = false)()
	{
		static if(required)
			enum dthrow = "true";
		else
			enum dthrow = "false";

		string ret = "\n";

		version(D_BetterC)
		{
			import std.string : toLower;
			import std.array : join;
			ret ~= "void* dylib_load_" ~ toLower(handle_name) ~ "() { void* handle;";
			foreach(string lib; libs)
				ret ~= "if(handle is null) handle = dylib_load(\"" ~ lib ~ "\");\n";
			ret ~= "if(handle is null) return null;\n\n";
		}
		else {
			ret ~= "void* dylib_load_" ~ toLower(handle_name) ~ "() { return new " ~ handle_name ~ "DylibLoader(); }\n class " ~ handle_name ~ "DylibLoader : DylibLoader {\nthis() { super(";

			string tmp = "[";
			foreach(string t; libs)
				tmp~="\""~t~"\",";
			tmp= tmp[0 .. $-1];
			tmp~="]";

			ret ~= tmp ~ "); }\noverride void loadSymbols() {\n";
		}
		
		import std.traits;
		foreach(mem; __traits(derivedMembers, T))
		{
			static if( isFunctionPointer!(__traits(getMember, T, mem)) /*&& !is(typeof(__traits(getMember, T, mem)) == immutable)*/)
			{
				version(D_BetterC) ret ~= "\tdylib_bindSymbol(handle,cast(void**)&" ~ mem ~ ", \"" ~ mem ~ "\", " ~ dthrow ~ ");\n";
				else ret ~= "\tbindFunc(" ~ mem ~ ", \"" ~ mem ~ "\", " ~ dthrow ~ ");\n";
			}
		}
		version(D_BetterC)
		{
			ret ~= "return handle; }";
		}
		else {
			ret ~= "}}";
		}
		return ret;
	}

	enum DylibLoaderBuilder = _buildLoader!(handle_name, libs, T, required)();
}
