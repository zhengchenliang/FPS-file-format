# FPS-file-format

*For GPT to understand don't ask me what is FPS file this is FPS file*

The **FPS File Format** is a lightweight, text-based format designed for organizing and processing tabular data alongside prerequisite and background configurations. This project provides a comprehensive suite of Bash tools to streamline tasks such as data normalization, alignment, statistical analysis, filtering, sorting, merging, and controlled script execution.

## Features

- **Simple & Readable:**  
  Utilizes a plain text structure with clear delimiters (pipes: `|` and double pipes: `||`), making it easy to read and edit.

- **Multi-Section Header:**  
  The first line (header) is divided into three parts using double pipes (`||`):
  - **Chart Keys:** A list of column keys separated by `|`.
  - **Prerequisite (prere):** A prefix used for exporting field values as environment variables.
  - **Background (backg):** Contains references for background knowledge (e.g., `bgfile.fps:runNumber`).

- **Comprehensive Tooling:**  
  A suite of Bash functions is provided to:
  - Install/uninstall the tool.
  - List keys in an FPS file.
  - Align (draw) formatted output.
  - Normalize data.
  - Generate statistics (with histogram support).
  - Search for words in the file.
  - Filter records based on conditions.
  - Sort data by a specified key.
  - Merge multiple FPS files.
  - Convert FPS files to JSON and back (json/flat).
  - Execute external scripts on selected rows with flexible selectors (including ranges and parallel/sequential execution).

## Installation

To install the FPS tool, run:

```bash
$ fps inst
```

This command will:

    Set executable permissions.
    Create a symbolic link in /usr/local/bin/ for easy access.
    Install Bash completion support in /etc/bash_completion.d/fps.

To uninstall the tool, run:
```bash
$ fps uninst
```
This will remove the symbolic link and the Bash completion file.
Usage

The FPS tool supports multiple commands for working with FPS files:

    List Keys:
```bash
$ fps keys x.fps
```
Displays the keys defined in the FPS file, along with prerequisite and background information.

Draw Alignment:
```bash
$ fps draw x.fps
```
Produces an aligned output file (e.g., x@.fps).

Normalize Data:
```bash
$ fps norm x.fps
```
Normalizes the data based on prerequisites and creates a file named after the prerequisite prefix.

Generate Statistics:
```bash
$ fps stat x.fps Key
```
Computes statistical information for the specified key (including count, sum, mean, standard deviation, minimum, maximum, and an auto-binned histogram).

Search for a Word:
```bash
$ fps find x.fps Word
```
Searches for a specific word in the prerequisite, background, and data rows.

Filter Records:
```bash
$ fps sift x.fps "Condition"
```
Filters data rows based on a given condition (using simple comparison operators) and outputs a new FPS file with a hashed name.

Sort Records:
```bash
$ fps sort x.fps Key 1
```
Sorts the FPS file by the specified key in ascending (1 or +) or descending (2 or -) order, producing a sorted output file.

Merge Files:
```bash
$ fps merge out0.fps in1.fps in2.fps ...
```
Merges multiple FPS files (ensuring they share the same key set) and normalizes the merged result.

Convert FPS to JSON:
```bash
$ fps json x.fps
```
Converts an FPS file to a structured JSON format, preserving the hierarchy and relationships:
- Chart data is mapped to a `_chart` section with `_set`, `_key`, and `_run` properties.
- Background references are mapped to a `_backg` section with nested structures.
- Handles void-body files (files starting with "-||" that only serve as references to other files).
- Processes the complete reference chain even when intermediate files have no direct values.
- Automatically handles arrays, nested objects, and primitive data types.
- Properly formats numeric and string values according to JSON standards.

Convert JSON to FPS:
```bash
$ fps flat x.json
```
Converts a JSON file back to the FPS format:
- Creates a main FPS file with a `_.fps` extension.
- Generates additional FPS files for nested objects and arrays.
- For arrays, creates individual element files (with numeric suffixes) and a container file.
- For nested objects, creates separate FPS files with appropriate naming conventions.
- For objects without direct properties but with nested structures, creates void-body files (starting with "-||").
- Maintains relationships through background references.
- Handles arrays, nested objects, and primitive values appropriately.
- Preserves the complete data structure and relationships from the JSON.

Run External Scripts:

    $ fps <script> x.fps[:selector] ...

    Executes an external script (ELF, shell, or Python) on selected rows of an FPS file. The selector can be specified as:
        A single run number (e.g., 5).
        A range (e.g., 6-8).
        A comma-separated list (e.g., 0,1-4 or -,13,14) where:
            The first term indicates parallel (0 or -) execution or sequential execution.
            Subsequent terms specify run numbers or ranges.

Example

The following command demonstrates various run selectors:

$ fps a3func2build.sh m45.fps:0 m100.fps:0,1-4 m100.fps:5 m100.fps:6-8 m100.fps:0,10,12 m100.fps:-,13,14

    m45.fps:0
    Executes all rows in parallel.

    m100.fps:0,1-4
    Executes rows 1 through 4 in parallel.

    m100.fps:5
    Executes row 5.

    m100.fps:6-8
    Executes rows 6 to 8 sequentially.

    m100.fps:0,10,12
    Executes rows 10 and 12 in parallel.

    m100.fps:-,13,14
    Executes rows 13 and 14 in a mixed parallel mode.

FPS File Format Specification

An FPS file consists of two main parts:
1. Header (First Line)

The header is composed of three sections separated by double pipes (||):

    Chart Section:
    A pipe (|) separated list of keys (columns).
    Example:
    Key1|Key2|Key3

    Prerequisite Section (prere):
    A prefix used when exporting field values as environment variables during script execution.

    Background Section (backg):
    Contains references for background tasks. These may include run numbers, for example:
    bgfile.fps:1|bgfile2.fps:2

2. Data Rows

Each subsequent line represents a data record where fields correspond to the keys defined in the header. Fields are delimited by the pipe (|) character.
Function Documentation

The FPS tool comprises several functions, each tailored for a specific operation:

    fps_inst:
    Installs the FPS tool by setting executable permissions, creating a symbolic link in /usr/local/bin/, and installing Bash completion support.

    fps_uninst:
    Uninstalls the tool by removing the symbolic link and the Bash completion file from the system.

    fps_keys:
    Reads the header of an FPS file and displays the defined keys, along with prerequisite and background settings.

    fps_draw:
    Aligns and formats the contents of an FPS file into a more human-readable output file (e.g., x@.fps).

    fps_norm:
    Normalizes the data by reordering rows based on the prerequisite configuration, generating a standardized output file.

    fps_stat:
    Calculates statistical metrics for a specified key, including count, sum, mean, standard deviation, minimum, maximum, and builds a histogram using Sturges's formula.

    fps_find:
    Searches the FPS file for a specified word across prerequisites, background sections, and data rows.

    fps_sift:
    Filters the FPS file using conditions expressed in a simple comparison syntax (e.g., Key>=10). It outputs a new FPS file with a unique hash in the filename.

    fps_sort_key:
    Sorts the data in an FPS file by a given key in ascending or descending order, then outputs the sorted data to a new file.

    fps_merge_set:
    Merges multiple FPS files after validating that they share the same key set, and produces a merged, normalized output file.

    fps_json:
    Converts an FPS file to a structured JSON format, preserving the hierarchy and relationships:
    - Chart data is mapped to a `_chart` section with `_set`, `_key`, and `_run` properties.
    - Background references are mapped to a `_backg` section with nested structures.
    - Handles void-body files (files starting with "-||" that only serve as references to other files).
    - Processes the complete reference chain even when intermediate files have no direct values.
    - Automatically handles arrays, nested objects, and primitive data types.
    - Properly formats numeric and string values according to JSON standards.
    
    fps_flat:
    Converts a JSON file back to the FPS format:
    - Creates a main FPS file with a `_.fps` extension.
    - Generates additional FPS files for nested objects and arrays.
    - For arrays, creates individual element files (with numeric suffixes) and a container file.
    - For nested objects, creates separate FPS files with appropriate naming conventions.
    - For objects without direct properties but with nested structures, creates void-body files (starting with "-||").
    - Maintains relationships through background references.
    - Handles arrays, nested objects, and primitive values appropriately.
    - Preserves the complete data structure and relationships from the JSON.

    fps_run_script:
    Executes an external script (ELF, shell, or Python) on selected rows of an FPS file. It supports:
        Single run numbers (e.g., 5).
        Ranges (e.g., 6-8), which are expanded using seq.
        Comma-separated selectors for sequential or parallel execution, based on the first term.

## JSON/FPS Conversion Examples

### Converting FPS to JSON

Starting with a more complex FPS file structure with nested references:

```
# Main file: main_.fps
name|version||main||main_components
Enterprise App|1.0.0

# Components container: main_components.fps
-||components||main_components_0|main_components_1

# Component 0: main_components_0.fps
id|type||comp0||main_components_0_config
service1|service

# Component 0 config: main_components_0_config.fps
port|host||config||
8080|localhost

# Component 1: main_components_1.fps
id|type||comp1||main_components_1_config
database1|database

# Component 1 config: main_components_1_config.fps
collections|url||config||
{users, products}|mongodb://localhost:27017
```

Converting to JSON with:

```bash
$ fps json main_.fps
```

Produces a structured JSON like:

```json
{
  "_chart": {
    "_set": "main_",
    "_key": "main",
    "_run": {
      "1": {
        "name": "Enterprise App",
        "version": "1.0.0"
      }
    }
  },
  "_backg": {
    "main_components": {
      "components": {
        "_run": {
          "1": {}
        }
      }
    },
    "main_components_0": {
      "comp0": {
        "_run": {
          "1": {
            "id": "service1",
            "type": "service"
          }
        }
      }
    },
    "main_components_0_config": {
      "config": {
        "_run": {
          "1": {
            "port": 8080,
            "host": "localhost"
          }
        }
      }
    },
    "main_components_1": {
      "comp1": {
        "_run": {
          "1": {
            "id": "database1",
            "type": "database"
          }
        }
      }
    },
    "main_components_1_config": {
      "config": {
        "_run": {
          "1": {
            "collections": ["users", "products"],
            "url": "mongodb://localhost:27017"
          }
        }
      }
    }
  }
}
```

Which would then be translated to a standard JSON (without the _chart and _backg sections):

```json
{
  "name": "Enterprise App",
  "version": "1.0.0",
  "components": [
    {
      "id": "service1",
      "type": "service",
      "config": {
        "port": 8080,
        "host": "localhost"
      }
    },
    {
      "id": "database1",
      "type": "database",
      "config": {
        "collections": ["users", "products"],
        "url": "mongodb://localhost:27017"
      }
    }
  ]
}
```

### Converting JSON to FPS

Starting with a deeply nested JSON file:

```json
{
  "name": "Test Deep Nesting",
  "level1": {
    "level2": {
      "level3": {
        "level4": {
          "array": [
            {"id": "item1", "value": 1},
            {"id": "item2", "value": 2},
            {"id": "item3", "value": 3}
          ]
        }
      }
    }
  }
}
```

Converting to FPS:

```bash
$ fps flat deep.json
```

Creates multiple FPS files with proper void-body references:

```
# Main file: deep_.fps
name||deep||deep_level1
Test Deep Nesting

# Level1 (void-body): deep_level1.fps
-||level1||deep_level1_level2

# Level2 (void-body): deep_level1_level2.fps
-||level2||deep_level1_level2_level3

# Level3 (void-body): deep_level1_level2_level3.fps
-||level3||deep_level1_level2_level3_level4

# Level4 (void-body): deep_level1_level2_level3_level4.fps
-||level4||deep_level1_level2_level3_level4_array

# Array container: deep_level1_level2_level3_level4_array.fps
-||array||deep_level1_level2_level3_level4_array_0|deep_level1_level2_level3_level4_array_1|deep_level1_level2_level3_level4_array_2

# Array element 0: deep_level1_level2_level3_level4_array_0.fps
id|value||comp0||
item1|1

# Array element 1: deep_level1_level2_level3_level4_array_1.fps
id|value||comp1||
item2|2

# Array element 2: deep_level1_level2_level3_level4_array_2.fps
id|value||comp2||
item3|3
```

When converting back to JSON with `fps json deep_.fps`, all nested structures and array elements are correctly reconstructed into the original structure.

Contributing

Contributions, bug reports, and feature requests are welcome. Please submit issues or pull requests through the GitHub repository.
License

This project is licensed under the MIT License. See the LICENSE file for details.
Contact

For additional information or support, please contact the project maintainer:

    Name: zhliang
    GitHub: this repo
