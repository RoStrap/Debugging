# Debugging Tools
In this repository are all of Nevermore's standard debugging tools.

## Standard Debug Module
This module has standard helper functions to assist in debugging.

### API
```lua

local Debug = require("Debug")

string Debug.TableToString (table [, tableName])
	-- Pretty self-explanatory
	-- @param table The table to convert into a string
	-- @param tableName Optional include tableName in formatting
	-- @returns a readable string of the table

string Debug.DirectoryToString (Object)
	-- A fixed version of GetFullName
	-- @param Object the Object to get the directory of
	-- @returns string A readable and properly formatted string of the directory
```
