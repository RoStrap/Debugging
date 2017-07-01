# Debugging Tools
In this repository are all of Nevermore's standard debugging tools.

## Standard Debug Module
This module has standard helper functions to assist in debugging.

### API
```lua
local Debug = require("Debug")
```

```cs
string Debug.TableToString (Table [, TableName])
	/// Pretty self-explanatory
	// @param table Table The table to convert into a string
	// @param string TableName [Optional]: Puts `local TableName = ` at the beginning
	// @returns a readable string of the table
```
```cs
string Debug.DirectoryToString (Object)
	/// A fixed version of GetFullName
	// @param Object the Object to get the directory of
	// @returns string A readable and properly formatted string of the directory
```
```cs
string Debug.EscapeString (String)
	/// Turns strings into Lua-readble format
	// @returns Objects location in proper Lua format
	// Useful for when you are doing string-intensive coding
	// Those minus signs are so tricky!
```
```cs
function Debug.AlphabeticalOrder (Table)
	/// Iteration function generator that allows for loops to be sequenced in alphabetical order
	// @param table Table That which will be iterated over in alphabetical order
	//	@constraints Currently only accepts tables with string keys
	// @returns function An iterative function that can traverse a table using a for loop
	// Not case-sensitive
```
