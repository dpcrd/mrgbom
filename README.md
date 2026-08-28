# mrgbom

A Bash script to merge an arbitrary number of BOMs, from several PCBs, possibly created with KiCAD, into a single CSV file, to ease the process of placing orders.

## Dependencies

- A Bash-like shell.
- SQLite3.

## BOM list

If the directory layout is as follows, the script can find CSV BOMS.

```
project/
├── pcb_project1
│   └── bom
│       └── pcb_project1.csv
└── pcb_project2
    └── BOM
        └── pcb_project2.csv
```

```shell
$ cd project
$ mrgbom -f
./pcb_project1/bom/pcb_project1.csv
./pcb_project2/BOM/pcb_project2.csv
$ mrgbom -f > bom_list.txt
```

Otherwise, the files should be listed manually in some text file.

## Usage

Type `mrgbom.sh -h` to get help and examples.

## Database

## Data structure

One SQL table is created for each PCB BOM.
The table schema relies on a configuration file for the [Interactive HTML BOM](https://github.com/openscopeproject/InteractiveHtmlBom) plugin for [KiCAD](https://www.kicad.org/), used to export the individual BOMs to CSV files.
These files are the inputs of this script.

Although this is subject to change as the plugin evolves or depending on the Linux distribution, a configuration file is provided for reference in the `kicad/` directory of this repository.
It was created by the plugin.
On Ubuntu 24.04.4 LTS, it is saved to `~/.local/share/kicad/$KICAD_VERSION/3rdparty/plugins/org_openscopeproject_InteractiveHtmlBom/config.ini`, where `$KICAD_VERSION` is e.g. "10.0".

## Mating parts

In the BOMs, an association can be made with a mating part, that is not truly a PCB part but needs to be ordered all the same.
This is often the case for connectors:
- The header, to be soldered on the PCB, is the main part, referenced in the `vendor` and `vendor_part_number` fields.
- The mating contact housing is referenced in the `mate_vendor` and `mate_vendor_part_number` fields in the header entry.

## Merging

The merge operation is delegated to the SQL script used to create the database.

In the SQLite3 database, a view is created to:
- Group the parts by `vendor` and `vendor_part_number`, summing the quantities, and picking the other fields from one of the BOMs.
- Add the mate parts to the list, creating new entries, using the following mapping:
  - `mate_vendor` &rarr; `vendor`
  - `mate_vendor_part_number` &rarr; `vendor_part_number`

## Export

Exporting the data exposed by the SQL view to a CSV file is then straightforward.
The CSV file can be imported in any spreadsheet editor.

Once the merged BOM is exported to CSV, the `.sql` and `.sqlite3` files are no longer needed and can be deleted.
