# lua-m3u-parser

![version](https://img.shields.io/badge/version-0.0.1-blue.svg?cacheSeconds=2592000)

A Lua package for parsing m3u files and extracting streams information. The package allows you to convert the parsed information into JSON or M3u format and provides various filtering and sorting options.

## Install

Using LuaRocks,

```sh
luarocks install m3u-parser
```

## Usage

Here is an example of how to use the M3uParser function:

```lua
local M3uParser = require("m3u-parser")

local url = "https://iptv-org.github.io/iptv/countries/np.m3u"
local useragent =
"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36"

-- Instantiate the parser
local parser = M3uParser({ timeout = 5, useragent = useragent })

-- Parse the m3u file
parser:parseM3u(url)

-- Remove by mp4 extension
parser:removeByExtension('mp4')

-- Filter streams by status
parser:filterBy('status', 'GOOD')

-- Get the table of streams
print(#parser:getList())

-- Convert streams to JSON and save to a file
parser:toFile('streams.json')
```

## API Reference

`M3uParser`
The main class that provides the functionality to parse m3u files and manipulate the streams information.

### Initialization

```lua
local parser = M3uParser({ useragent=defaultUseragent, timeout=5 })
```

- `useragent` (optional): User agent string for HTTP requests. Default is a Chrome User-Agent string.
- `timeout` (optional): Timeout duration for HTTP requests in seconds. Defaults to `5`.

### Methods

#### parseM3u

```lua
parseM3u(dataSource, options)
```

Parses the content of a local file or URL and extracts the streams information.

- `dataSource`: The path to the m3u file, which can be a local file path or a URL.
- `options` (optional):
  - `schemes` (table, optional): A table of allowed URL schemes. Default is `{"http", "https"}`.
  - `statusChecker` (table, optional): A dictionary mapping URL schemes to custom status checker functions. Default is `{}`.
  - `checkLive` (boolean, optional): Indicates whether to check the status of live streams (default is `true`).
  - `enforceSchema` (boolean, optional): Indicates whether to enforce a specific schema for parsed data.
        If enforced, non-existing fields in a stream are filled with nil.
        If not enforced, non-existing fields are ignored. Default is `true`.

You can define your own custom status checker function for schemes. If no status checker is defined, then the default status checker is used. The default status checker works for `http` and `https` url schemes only.

```lua
function ftpChecker(url):
    # Checker implementation
    # Return either true for good status or false for bad status
    return true

parser:parseM3u(path, { schemes={'http', 'https', 'ftp'}, statusChecker={"ftp": ftpChecker}, checkLive=true, enforceSchema=true})
```

#### parseJson

```lua
parseJson(dataSource, options)
```

Parses the content of a local file or URL and extracts the streams information.

- `dataSource`: The path to the json file, which can be a local file path or a URL.
- `options` (optional):
  - `schemes` (table, optional): A table of allowed URL schemes. Default is `{"http", "https"}`.
  - `statusChecker` (table, optional): A dictionary mapping URL schemes to custom status checker functions. Default is `{}`.
  - `checkLive` (boolean, optional): Indicates whether to check the status of live streams (default is `true`).
  - `enforceSchema` (boolean, optional): Indicates whether to enforce a specific schema for parsed data.
        If enforced, non-existing fields in a stream are filled with nil.
        If not enforced, non-existing fields are ignored. Default is `true`.

You can define your own custom status checker function for schemes. If no status checker is defined, then the default status checker is used. The default status checker works for `http` and `https` url schemes only.

```lua
function ftpChecker(url):
    # Checker implementation
    # Return either true for good status or false for bad status
    return true

parser:parseJson(path, { schemes={'http', 'https', 'ftp'}, status_checker={"ftp": ftpChecker}, check_live=true, enforce_schema=true })
```

#### filterBy

```lua
filterBy(key, filters, options)
```

Filters the streams information based on a key and filter/s.

- `key`: The key to filter on, can be a single key or nested key (e.g., "language-name").
- `filters`: The filter word/s to perform the filtering operation.
- `options` (optional):
  - `keySplitter` (string, optional): A string used to split nested keys (default is `"-"`).
  - `retrieve` (boolean, optional): Indicates whether to retrieve or remove based on the filter key (default is `true`).
  - `nestedKey` (boolean, optional): Indicates whether the filter key is nested or not (default is `false`).

```lua
parser:filterBy(key, filters, { keySplitter="-", retrieve=true, nestedKey=false })
```

#### resetOperations

`resetOperations()`

Resets the streams information table to the initial state before any filtering or sorting operations.

```lua
parser:resetOperations()
```

#### removeByExtension

`removeByExtension(extensions)`

Removes stream information with a certain extension(s).

- `extensions`: The name of the extension(s) to remove, e.g., "mp4" or {"mp4", "m3u8"}.

```lua
parser:removeByExtension(extensions)
```

#### retrieveByExtension

`retrieveByExtension(extensions)`

Retrieves only stream information with a certain extension(s).

- `extensions`: The name of the extension(s) to retrieve, e.g., "mp4" or {"mp4", "m3u8"}.

```lua
parser:retrieveByExtension(extensions)
```

#### removeByCategory

`removeByCategory(categories)`

Removes stream information containing certain categories.

- `categories`: Category or table of categories to be removed from the streams information

```lua
parser:removeByCategory(categories)
```

#### retrieveByCategory

`retrieveByCategory(categories)`

Selects only stream information containing certain categories.

- `categories`: Category or table of categories to be retrieved from the streams information.

```lua
parser:retrieveByCategory(categories)
```

#### sortBy

```lua
sortBy(key, options)
```

Sorts the streams information based on a key in ascending or descending order.

- `key`: The key to sort on, can be a single key or nested key seperated by `keySplitter` (e.g., "language-name").
- `options` (optional):
  - `keySplitter` (string, optional): A string used to split nested keys (default is `"-"`).
  - `asc` (boolean, optional): Indicates whether to sort in ascending (true) or descending (false) order (default is `true`).
  - `nestedKey` (boolean, optional): Indicates whether the sort key is nested or not (default is `false`).

```lua
parser:sortBy(key, { keySplitter="-", asc=true, nestedKey=false })
```

#### removeDuplicates

`removeDuplicates(name, url)`

Removes duplicate stream entries based on the provided 'name' pattern and exact 'url' match or remove all duplicates if name and url is not provided.
  
- `name` (string, optional): The name pattern to filter duplicates. Defaults to `nil`.
- `url` (string, optional): The exact URL to filter duplicates. Defaults to `nil`.

```lua
parser:removeDuplicates()
# or
parser:removeDuplicates("Channel 1", "http://example.com/stream1")
```

### getJson

`getJson()`

Returns the streams information in JSON format.

```lua
local jsonData = parser:getJson()
```

### getList

`getList()`

Returns the table of streams information after any filtering or sorting operations.

```lua
local streams = parser:getList()
```

### toFile

`toFile(filename, format)`

Saves the streams information to a file in the specified format.

- `filename`: The name of the output file.
- `format` (optional): The output file format, either "json" or "csv". Default is `"json"`.

```lua
parser:toFile(filename, "json")
```

## Other Implementations

- `Python`: [m3u-parser](https://github.com/pawanpaudel93/m3u-parser)
- `Golang`: [go-m3u-parser](https://github.com/pawanpaudel93/go-m3u-parser)
- `Rust`: [rs-m3u-parser](https://github.com/pawanpaudel93/rs-m3u-parser)
- `Typescript`: [ts-m3u-parser](https://github.com/pawanpaudel93/ts-m3u-parser)

## Author

👤 **Pawan Paudel**

- Github: [@pawanpaudel93](https://github.com/pawanpaudel93)

## 🤝 Contributing

Contributions, issues and feature requests are welcome! \ Feel free to check [issues page](https://github.com/pawanpaudel93/lua-m3u-parser/issues).

## Show your support

Give a ⭐️ if this project helped you!

Copyright © 2024 [Pawan Paudel](https://github.com/pawanpaudel93).
