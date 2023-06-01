# NASCAM All-Sky Imager Raw PGM Data Readfile

[![Github Actions - Tests](https://github.com/ucalgary-aurora/nascam-imager-readfile/workflows/tests/badge.svg)](https://github.com/ucalgary-aurora/nascam-imager-readfile/actions?query=workflow%3Atests)
[![PyPI version](https://img.shields.io/pypi/v/nascam-imager-readfile.svg)](https://pypi.python.org/pypi/nascam-imager-readfile/)
[![MIT license](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/ucalgary-aurora/nascam-imager-readfile/blob/main/LICENSE)
[![PyPI Python versions](https://img.shields.io/badge/python-3.7%20%7C%203.8%20%7C%203.9%20%7C%203.10-blue)](https://pypi.python.org/pypi/nascam-imager-readfile/)

Python library for reading NASCAM All-Sky Imager (ASI) stream0 raw PNG-file data. The data can be found at https://data.phys.ucalgary.ca.

## Supported Datasets

- NASCAM ASI raw: [stream0.png](https://data.phys.ucalgary.ca/sort_by_project/NORSTAR/nascam-msi/stream0.png) PNG files

## Installation

The nascam-imager-readfile library is available on PyPI:

```console
$ python3 -m pip install nascam-imager-readfile
```

## Supported Python Versions

nascam-imager-readfile officially supports Python 3.8+.

## Examples

Example Python notebooks can be found in the "examples" directory. Further, some examples can be found in the "Usage" section below.

## Usage

Import the library using `import nascam_imager_readfile`

**Warning**: On Windows, be sure to put any `read` calls into a `main()` method. This is because we utilize the multiprocessing library and the method of forking processes in Windows requires it. Note that if you're using Jupyter or other IPython-based interfaces, this is not required.

### Read a single file

```python
>>> import nascam_imager_readfile
>>> filename = "path/to/data/2010/01/01/atha_nascam-iccd04/ut06/20100101_0600_atha_nascam-iccd04.png.tar"
>>> img, meta, problematic_files = nascam_imager_readfile.read(filename)
```

### Read multiple files

```python
>>> import nascam_imager_readfile, glob
>>> file_list = glob.glob("path/to/files/2010/01/01/atha_nascam-iccd04/ut06/*.tar")
>>> img, meta, problematic_files = nascam_imager_readfile.read(file_list)
```

### Read using multiple worker processes

```python
>>> import nascam_imager_readfile, glob
>>> file_list = glob.glob("path/to/files/2010/01/01/atha_nascam-iccd04/ut06/*.tar")
>>> img, meta, problematic_files = nascam_imager_readfile.read(file_list, workers=4)
```

### Read with no output

```python
>>> import nascam_imager_readfile, glob
>>> file_list = glob.glob("path/to/files/2010/01/01/atha_nascam-iccd04/ut06/*.tar")
>>> img, meta, problematic_files = nascam_imager_readfile.read(file_list, workers=4, quiet=True)
```

## Development

Clone the repository and install dependencies using Poetry.

```console
$ git clone https://github.com/ucalgary-aurora/nascam-imager-readfile.git
$ cd nascam-imager-readfile/python
$ make install
```

## Testing

```console
$ make test
[ or do each test separately ]
$ make test-flake8
$ make test-pylint
$ make test-pytest
```
