# NASCAM All-Sky Imager Raw PNG Data Readfile

![idl-required](https://img.shields.io/badge/IDL-6.0%2B-lightgrey)
![license](https://img.shields.io/badge/license-MIT-brightgreen)

IDL procedures for reading NASCAM All-Sky Imager (ASI) stream0 raw PGM-file data. The data can be found at https://data.phys.ucalgary.ca.

## Requirements

- IDL 6.0+ is required
- Windows 7/10, Linux

## Supported Datasets

- NASCAM ASI raw: [stream0.png](https://data.phys.ucalgary.ca/sort_by_project/NORSTAR/nascam-msi/stream0.png) PNG files

## Installation

Download the programs and include in your IDL Path or compile manually as needed.

## Usage Examples

This readfile can be used in a couple of different ways. Below are a few ways:

1) read a single file
2) read a list of files

### Read a single one-minute file

```
IDL> themis_imager_readfile_new,filename,img,meta
IDL> help,img
IMG             UINT      = Array[256, 256, 20]
IDL> help,meta
META            STRUCT    = -> THEMIS_IMAGER_METADATA Array[20]
```

### Read multiple files (ie. one hour worth)

```
IDL> f=file_search("C:\path\to\files\for\an\hour\*")
IDL> themis_imager_readfile_new,f,img,meta
IDL> help,img
IMG             UINT      = Array[256, 256, 1200]
IDL> help,meta
META            STRUCT    = -> THEMIS_IMAGER_METADATA Array[1200]
```
